{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.dst-server;

  # Import config templates
  clusterIniTemplate = import ../config-templates/cluster.ini.nix;
  masterIniTemplate = import ../config-templates/server-master.ini.nix;
  cavesIniTemplate = import ../config-templates/server-caves.ini.nix;

  # Generate config content
  clusterIniContent = clusterIniTemplate cfg;
  masterIniContent = masterIniTemplate cfg;
  cavesIniContent = cavesIniTemplate cfg;

  # Determine server binary based on architecture
  serverBin = if cfg.architecture == "x64"
    then "${cfg.serverInstallDir}/bin64/dontstarve_dedicated_server_nullrenderer_x64"
    else "${cfg.serverInstallDir}/bin/dontstarve_dedicated_server_nullrenderer";

  # Wrapper script - nixpkgs curl already includes libcurl-gnutls.so.4
  wrappedServerBin = pkgs.writeShellScript "dst-server-wrapper" ''
    export LD_LIBRARY_PATH="${lib.makeLibraryPath (with pkgs; [ curl glibc stdenv.cc.cc.lib zlib gnutls nettle ])}"
    exec ${serverBin} "$@"
  '';

  # Generate dedicated_server_mods_setup.lua from mods list
  modsSetupContent = ''
    ${concatMapStringsSep "\n" (modId: ''ServerModSetup("${modId}")'') cfg.mods}
  '';

  # Common preStart script for both services
  makePreStartScript = shardName: pkgs.writeShellScript "dst-server-${shardName}-prestart" ''
    set -e

    # Create directory structure
    mkdir -p ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/{Master,Caves,mods}
    mkdir -p ${cfg.dataDir}/.klei/ugc
    mkdir -p ${cfg.dataDir}/DoNotStarveTogether/Agreements

    # Copy cluster token and remove trailing newline
    if [ -f "${cfg.clusterTokenFile}" ]; then
      tr -d '\n' < "${cfg.clusterTokenFile}" > ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/cluster_token.txt
      chmod 600 ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/cluster_token.txt
    else
      echo "Error: Cluster token file not found at ${cfg.clusterTokenFile}"
      exit 1
    fi

    # Copy default configs if they don't exist (non-destructive)
    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/cluster.ini ]; then
      cat > ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/cluster.ini <<'EOF'
${clusterIniContent}
EOF
    fi

    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Master/server.ini ]; then
      cat > ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Master/server.ini <<'EOF'
${masterIniContent}
EOF
    fi

    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Caves/server.ini ]; then
      cat > ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Caves/server.ini <<'EOF'
${cavesIniContent}
EOF
    fi

    # Copy worldgenoverride files if they don't exist
    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Master/worldgenoverride.lua ]; then
      cp ${../config-templates/worldgenoverride-master.lua} ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Master/worldgenoverride.lua
    fi

    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Caves/worldgenoverride.lua ]; then
      cp ${../config-templates/worldgenoverride-caves.lua} ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/Caves/worldgenoverride.lua
    fi

    # Copy modsettings.lua if it doesn't exist
    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/mods/modsettings.lua ]; then
      cp ${../config-templates/mods/modsettings.lua} ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/mods/modsettings.lua
    fi

    # Copy agreements.ini
    if [ ! -f ${cfg.dataDir}/DoNotStarveTogether/Agreements/agreements.ini ]; then
      cp ${../config-templates/agreements.ini} ${cfg.dataDir}/DoNotStarveTogether/Agreements/agreements.ini
    fi

    # Generate dedicated_server_mods_setup.lua
    cat > ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/mods/dedicated_server_mods_setup.lua <<'EOF'
${modsSetupContent}
EOF

    # Auto-update server if enabled
    ${optionalString cfg.autoUpdate ''
      echo "Updating DST server..."
      mkdir -p ${cfg.serverInstallDir}
      ${pkgs.steamcmd}/bin/steamcmd \
        +force_install_dir ${cfg.serverInstallDir} \
        +login anonymous \
        +app_update 343050 validate \
        +quit
    ''}

    # Create mods symlink if it doesn't exist
    if [ ! -L ${cfg.serverInstallDir}/mods ]; then
      rm -rf ${cfg.serverInstallDir}/mods
      ln -sf ${cfg.dataDir}/DoNotStarveTogether/Cluster_1/mods ${cfg.serverInstallDir}/mods
    fi

    # Update mods using DST server
    if [ -f "${serverBin}" ] && [ ${toString (length cfg.mods)} -gt 0 ]; then
      echo "Updating mods..."
      ${wrappedServerBin} \
        -only_update_server_mods \
        -persistent_storage_root ${cfg.dataDir} \
        -ugc_directory ${cfg.dataDir}/.klei/ugc \
        -cluster Cluster_1 \
        -shard ${shardName} || true
    fi

  '';

  # Common service configuration
  makeServiceConfig = shardName: {
    description = "Don't Starve Together ${shardName} Shard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ] ++ optional (shardName == "Caves") "dst-server-master.service";
    requires = optionals (shardName == "Caves") [ "dst-server-master.service" ];

    preStart = toString (makePreStartScript shardName);

    serviceConfig = {
      Type = "simple";
      User = cfg.user;
      Group = cfg.group;
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStopSec = "720s";

      ExecStart = "${wrappedServerBin} -skip_update_server_mods -persistent_storage_root ${cfg.dataDir} -ugc_directory ${cfg.dataDir}/.klei/ugc -cluster Cluster_1 -shard ${shardName}";

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ cfg.dataDir cfg.serverInstallDir ];
    };

    path = with pkgs; [ steamcmd bash coreutils ];

    environment = {
      HOME = cfg.dataDir;
    };
  };

in {
  options.services.dst-server = {
    enable = mkEnableOption "Don't Starve Together dedicated server";

    clusterName = mkOption {
      type = types.str;
      default = "NixOS DST Server";
      description = "The name of your server cluster as shown in the server browser";
    };

    clusterDescription = mkOption {
      type = types.str;
      default = "A Don't Starve Together server running on NixOS";
      description = "A description of your server shown in the server browser";
    };

    clusterPassword = mkOption {
      type = types.str;
      default = "";
      description = "Password required to join the server (empty for no password)";
    };

    clusterTokenFile = mkOption {
      type = types.path;
      description = ''
        Path to the cluster token file. This is required to run a DST server.
        Get your token from https://accounts.klei.com/account/game/servers?game=DontStarveTogether
      '';
    };

    maxPlayers = mkOption {
      type = types.ints.between 1 64;
      default = 16;
      description = "Maximum number of players allowed on the server";
    };

    gameMode = mkOption {
      type = types.enum [ "survival" "endless" "wilderness" ];
      default = "endless";
      description = "Game mode: survival (respawn at portal), endless (respawn at portal, no darkness penalty), wilderness (respawn as ghost)";
    };

    pvpEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable player vs player combat";
    };

    pauseWhenEmpty = mkOption {
      type = types.bool;
      default = true;
      description = "Pause the game when no players are connected";
    };

    ports = {
      master = mkOption {
        type = types.port;
        default = 10999;
        description = "Game port for the master (overworld) shard";
      };

      masterSteam = mkOption {
        type = types.port;
        default = 12346;
        description = "Steam master server port for the master shard";
      };

      caves = mkOption {
        type = types.port;
        default = 11000;
        description = "Game port for the caves shard";
      };

      cavesSteam = mkOption {
        type = types.port;
        default = 12347;
        description = "Steam master server port for the caves shard";
      };

      shardMaster = mkOption {
        type = types.port;
        default = 10998;
        description = "Port for inter-shard communication (master shard listens on this)";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically open firewall ports for the server";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/dst-server";
      description = "Directory for server data, saves, and configuration";
    };

    serverInstallDir = mkOption {
      type = types.path;
      default = "/var/lib/dst-server-install";
      description = "Directory where the DST server binaries are installed";
    };

    user = mkOption {
      type = types.str;
      default = "dst";
      description = "User account under which the DST server runs";
    };

    group = mkOption {
      type = types.str;
      default = "dst";
      description = "Group under which the DST server runs";
    };

    autoUpdate = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically update the server on start";
    };

    architecture = mkOption {
      type = types.enum [ "x86" "x64" ];
      default = "x64";
      description = "Server architecture (x86 for 32-bit, x64 for 64-bit)";
    };

    mods = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of Steam Workshop mod IDs to install";
      example = [ "350811795" "378160973" ];
    };

    extraClusterConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional configuration to append to cluster.ini";
    };

    extraMasterConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional configuration to append to Master/server.ini";
    };

    extraCavesConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional configuration to append to Caves/server.ini";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Don't Starve Together server user";
    };

    users.groups.${cfg.group} = {};

    # Configure firewall
    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.ports.master
        cfg.ports.caves
        cfg.ports.masterSteam
        cfg.ports.cavesSteam
      ];
    };

    # Create systemd services
    systemd.services.dst-server-master = makeServiceConfig "Master";
    systemd.services.dst-server-caves = makeServiceConfig "Caves";

    # Ensure server install directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.serverInstallDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
    ];
  };
}

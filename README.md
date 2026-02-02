# Don't Starve Together NixOS Module

A NixOS module for running a Don't Starve Together dedicated server natively (without Docker).

## Features

- Native NixOS systemd service (no Docker required)
- Automatic server updates via SteamCMD
- Support for mods from Steam Workshop
- Dual-shard setup (Overworld + Caves)
- Declarative configuration via Nix
- Automatic firewall configuration
- Helper scripts for management

## Quick Start

### 1. Get a Cluster Token

You need a cluster token from Klei to run a DST server:

```bash
nix run .#generate-token
```

Visit https://accounts.klei.com/account/game/servers?game=DontStarveTogether and follow the instructions.

Save your token to a file:
```bash
sudo mkdir -p /var/lib/dst-server
echo "YOUR_TOKEN_HERE" | sudo tee /var/lib/dst-server/cluster_token.txt
sudo chmod 600 /var/lib/dst-server/cluster_token.txt
```

### 2. Add to Your NixOS Configuration

Add this flake to your system's `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "path:/home/boid/projects/dst-server/nix";
    # Or use git: "git+file:///home/boid/projects/dst-server/nix"
  };

  outputs = { nixpkgs, dst-server, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        dst-server.nixosModules.default
        {
          services.dst-server = {
            enable = true;
            clusterName = "My NixOS Server";
            clusterDescription = "A friendly DST server";
            clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
            maxPlayers = 16;
            gameMode = "endless";
            openFirewall = true;
          };
        }
      ];
    };
  };
}
```

Or in traditional NixOS configuration:

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    /home/boid/projects/dst-server/nix/modules/dst-server.nix
  ];

  services.dst-server = {
    enable = true;
    clusterName = "My NixOS Server";
    clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
    openFirewall = true;
  };
}
```

### 3. Apply Configuration

```bash
sudo nixos-rebuild switch
```

### 4. Check Status

```bash
systemctl status dst-server-master.service
systemctl status dst-server-caves.service

# View logs
journalctl -u dst-server-master.service -f
```

## Configuration Options

### Basic Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the DST server |
| `clusterName` | string | `"NixOS DST Server"` | Server name in browser |
| `clusterDescription` | string | `"A Don't Starve..."` | Server description |
| `clusterPassword` | string | `""` | Password (empty = no password) |
| `clusterTokenFile` | path | *required* | Path to cluster token file |
| `maxPlayers` | int (1-64) | `16` | Maximum players |
| `gameMode` | enum | `"endless"` | `survival`, `endless`, or `wilderness` |
| `pvpEnabled` | bool | `false` | Enable PvP combat |
| `pauseWhenEmpty` | bool | `true` | Pause when no players |

### Port Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ports.master` | port | `10999` | Master shard game port |
| `ports.masterSteam` | port | `12346` | Master Steam port |
| `ports.caves` | port | `11000` | Caves shard game port |
| `ports.cavesSteam` | port | `12347` | Caves Steam port |
| `ports.shardMaster` | port | `10998` | Inter-shard communication |

### Advanced Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `openFirewall` | bool | `false` | Auto-configure firewall |
| `dataDir` | path | `"/var/lib/dst-server"` | Server data directory |
| `serverInstallDir` | path | `"/var/lib/dst-server-install"` | Binary install location |
| `user` | string | `"dst"` | Service user |
| `group` | string | `"dst"` | Service group |
| `autoUpdate` | bool | `true` | Auto-update on start |
| `architecture` | enum | `"x64"` | `x86` or `x64` |
| `mods` | list | `[]` | Steam Workshop mod IDs |
| `extraClusterConfig` | lines | `""` | Extra cluster.ini config |
| `extraMasterConfig` | lines | `""` | Extra Master/server.ini config |
| `extraCavesConfig` | lines | `""` | Extra Caves/server.ini config |

## Examples

### Server with Mods

```nix
services.dst-server = {
  enable = true;
  clusterName = "Modded Server";
  clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  maxPlayers = 32;
  openFirewall = true;

  mods = [
    "350811795"  # Geometric Placement
    "378160973"  # Global Positions
    "666155465"  # Show Me
  ];
};
```

### PvP Server

```nix
services.dst-server = {
  enable = true;
  clusterName = "PvP Arena";
  clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  gameMode = "survival";
  pvpEnabled = true;
  pauseWhenEmpty = false;
  maxPlayers = 24;
  openFirewall = true;
};
```

### Custom Ports

```nix
services.dst-server = {
  enable = true;
  clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";

  ports = {
    master = 20999;
    masterSteam = 22346;
    caves = 21000;
    cavesSteam = 22347;
    shardMaster = 20998;
  };

  openFirewall = true;
};
```

## Management

### View Logs

```bash
# Both shards
journalctl -u dst-server-master.service -u dst-server-caves.service -f

# Master only
journalctl -u dst-server-master.service -f

# Caves only
journalctl -u dst-server-caves.service -f
```

### Restart Services

```bash
# Restart both (caves depends on master)
systemctl restart dst-server-caves.service dst-server-master.service

# Restart master only
systemctl restart dst-server-master.service

# Restart caves only
systemctl restart dst-server-caves.service
```

### Stop/Start Services

```bash
systemctl stop dst-server-caves.service dst-server-master.service
systemctl start dst-server-master.service dst-server-caves.service
```

### Update Server

The server auto-updates on start if `autoUpdate = true` (default). To manually update:

```bash
systemctl restart dst-server-caves.service dst-server-master.service
```

## File Locations

- **Server data**: `/var/lib/dst-server/DoNotStarveTogether/`
- **Server binaries**: `/var/lib/dst-server-install/`
- **Cluster config**: `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/cluster.ini`
- **Master config**: `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/Master/server.ini`
- **Caves config**: `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/Caves/server.ini`
- **Mods**: `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/mods/`

## Manual Configuration

After initial setup, you can manually edit config files in `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/`. Changes persist across restarts but will be overwritten if you delete the files (they'll regenerate from Nix templates).

To preserve manual changes:
1. Edit files directly in the data directory
2. Don't delete config files
3. Use `extraClusterConfig`, `extraMasterConfig`, `extraCavesConfig` options to append additional settings

## Troubleshooting

### Server won't start

Check logs:
```bash
journalctl -u dst-server-master.service -n 50
```

Common issues:
- Invalid cluster token
- Cluster token file has wrong permissions (should be 600)
- Ports already in use
- Insufficient disk space

### Mods not loading

1. Check mod IDs are correct (from Steam Workshop URLs)
2. Verify mods are listed in config:
```bash
cat /var/lib/dst-server/DoNotStarveTogether/Cluster_1/mods/dedicated_server_mods_setup.lua
```
3. Check logs for mod download errors:
```bash
journalctl -u dst-server-master.service | grep -i mod
```

### Can't connect to server

1. Check firewall is open:
```bash
sudo nft list ruleset | grep 10999
```

2. Verify ports are listening:
```bash
ss -tulpn | grep dontstarve
```

3. Check server is running:
```bash
systemctl status dst-server-master.service
```

### Permission errors

Fix ownership:
```bash
sudo chown -R dst:dst /var/lib/dst-server
sudo chown -R dst:dst /var/lib/dst-server-install
```

## Development

### Build and Test

```bash
# Check flake
nix flake check

# Show flake outputs
nix flake show

# Build helper scripts
nix build .#dst-server-scripts

# Enter dev shell
nix develop
```

### Format Code

```bash
nix develop
nixpkgs-fmt .
```

## Architecture

- **systemd services**: `dst-server-master.service` and `dst-server-caves.service`
- **Process management**: systemd (replaces supervisor from Docker setup)
- **Dependencies**: Caves service depends on Master service
- **Updates**: SteamCMD handles server and mod updates
- **Configuration**: Three-layer approach:
  1. Nix options → generate configs
  2. Generated configs → copied to dataDir on first run
  3. User manual edits → preserved across restarts

## Migration from Docker

This Nix implementation is functionally equivalent to the Docker setup in `docker-dst-server/`. Key differences:

| Docker | Nix |
|--------|-----|
| Supervisor | systemd |
| Container | Native process |
| Environment variables | Nix options |
| entrypoint.sh | systemd preStart |
| Manual volume setup | Automatic directory creation |

## License

Same as the original docker-dst-server project.

## Credits

Based on [Jamesits/docker-dst-server](https://github.com/Jamesits/docker-dst-server)

# Example NixOS configuration for Don't Starve Together server
#
# This file shows various configuration examples.
# Choose one and adapt it to your needs.

{ config, pkgs, ... }:

{
  imports = [
    ./modules/dst-server.nix
  ];

  # === BASIC CONFIGURATION ===
  # Minimal working configuration
  services.dst-server = {
    enable = true;
    clusterName = "My DST Server";
    clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
    openFirewall = true;
  };

  # === MODDED SERVER ===
  # Server with popular mods
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "Modded Adventure Server";
  #   clusterDescription = "Server with quality-of-life mods";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #   maxPlayers = 24;
  #   gameMode = "endless";
  #   openFirewall = true;
  #
  #   mods = [
  #     "350811795"  # Geometric Placement
  #     "378160973"  # Global Positions
  #     "666155465"  # Show Me
  #     "375859599"  # Health Info
  #     "362175979"  # Wormhole Marks
  #   ];
  # };

  # === PVP SERVER ===
  # Competitive PvP configuration
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "PvP Arena";
  #   clusterDescription = "Competitive PvP server - fight for survival!";
  #   clusterPassword = "pvp123";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #   maxPlayers = 32;
  #   gameMode = "survival";
  #   pvpEnabled = true;
  #   pauseWhenEmpty = false;
  #   openFirewall = true;
  # };

  # === PRIVATE SERVER ===
  # Password-protected server for friends
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "Friends Only";
  #   clusterDescription = "Private server for friends";
  #   clusterPassword = "secretpassword";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #   maxPlayers = 8;
  #   gameMode = "endless";
  #   pauseWhenEmpty = true;
  #   openFirewall = true;
  # };

  # === CUSTOM PORTS ===
  # Run on non-default ports (useful for multiple servers)
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "Custom Port Server";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #
  #   ports = {
  #     master = 20999;
  #     masterSteam = 22346;
  #     caves = 21000;
  #     cavesSteam = 22347;
  #     shardMaster = 20998;
  #   };
  #
  #   openFirewall = true;
  # };

  # === ADVANCED CONFIGURATION ===
  # Custom settings with extra config
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "Advanced Server";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #   maxPlayers = 64;
  #   openFirewall = true;
  #
  #   # Extra cluster configuration
  #   extraClusterConfig = ''
  #     [NETWORK]
  #     tick_rate = 30
  #
  #     [STEAM]
  #     steam_group_only = true
  #     steam_group_id = 123456789
  #   '';
  #
  #   # Extra master shard configuration
  #   extraMasterConfig = ''
  #     [NETWORK]
  #     server_port = 10999
  #   '';
  #
  #   # Extra caves shard configuration
  #   extraCavesConfig = ''
  #     [NETWORK]
  #     server_port = 11000
  #   '';
  # };

  # === NO AUTO-UPDATE ===
  # Disable automatic updates (use specific server version)
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "Stable Version Server";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #   autoUpdate = false;
  #   openFirewall = true;
  # };

  # === 32-BIT SERVER ===
  # Run 32-bit server binary (if needed for compatibility)
  # services.dst-server = {
  #   enable = true;
  #   clusterName = "32-bit Server";
  #   clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  #   architecture = "x86";
  #   openFirewall = true;
  # };
}

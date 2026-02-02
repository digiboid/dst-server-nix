# Quick Start Guide

Get your Don't Starve Together server running in 5 minutes!

## Prerequisites

- NixOS system with flakes enabled
- Internet connection for downloading server files

## Step 1: Get Your Cluster Token (2 minutes)

1. Visit: https://accounts.klei.com/account/game/servers?game=DontStarveTogether
2. Log in with your Klei account
3. Click "Add New Server"
4. Copy the generated token
5. Save it to a file:

```bash
sudo mkdir -p /var/lib/dst-server
echo "YOUR_TOKEN_HERE" | sudo tee /var/lib/dst-server/cluster_token.txt
sudo chmod 600 /var/lib/dst-server/cluster_token.txt
```

## Step 2: Add to Your NixOS Configuration (2 minutes)

### If you use flakes:

Edit your main flake (e.g., `/etc/nixos/flake.nix` or `~/nixconf/flake.nix`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "path:/home/boid/projects/dst-server/nix";
  };

  outputs = { nixpkgs, dst-server, ... }: {
    nixosConfigurations.YOUR-HOSTNAME = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        dst-server.nixosModules.default
        {
          services.dst-server = {
            enable = true;
            clusterName = "My Server";
            clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
            openFirewall = true;
          };
        }
      ];
    };
  };
}
```

Replace `YOUR-HOSTNAME` with your actual hostname (find it with `hostname`).

### If you don't use flakes:

Edit `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    /home/boid/projects/dst-server/nix/modules/dst-server.nix
  ];

  services.dst-server = {
    enable = true;
    clusterName = "My Server";
    clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
    openFirewall = true;
  };

  # ... rest of your config
}
```

## Step 3: Apply Configuration (1 minute)

```bash
# With flakes
sudo nixos-rebuild switch --flake /etc/nixos#YOUR-HOSTNAME

# Without flakes
sudo nixos-rebuild switch
```

The first run will:
- Download and install the DST server (takes 3-5 minutes)
- Set up systemd services
- Configure firewall
- Start the server

## Step 4: Verify It's Running

```bash
# Check service status
systemctl status dst-server-master.service
systemctl status dst-server-caves.service

# View logs
journalctl -u dst-server-master.service -f
```

Look for messages like:
```
Your Server GUID: KU_xxxxxxxx
Sim paused
```

## Step 5: Join Your Server

1. Launch Don't Starve Together
2. Click "Browse Games"
3. Look for your server name
4. Click "Join Game"

## Common Issues

### "Invalid cluster token"
- Double-check your token at https://accounts.klei.com/account/game/servers?game=DontStarveTogether
- Make sure there's no extra whitespace or newline in the token file

### "Port already in use"
- Another service is using the default ports
- Change ports in your configuration:
```nix
services.dst-server.ports = {
  master = 20999;
  caves = 21000;
  # ... etc
};
```

### "Can't find server in browser"
- Wait 1-2 minutes for the server to fully start
- Check firewall: `sudo nft list ruleset | grep 10999`
- Verify ports are open: `ss -tulpn | grep 10999`

### "Permission denied"
- Fix ownership: `sudo chown -R dst:dst /var/lib/dst-server`

## Next Steps

### Add Mods

Edit your configuration:
```nix
services.dst-server = {
  # ... existing config ...
  mods = [
    "350811795"  # Geometric Placement
    "378160973"  # Global Positions
    "666155465"  # Show Me
  ];
};
```

Rebuild: `sudo nixos-rebuild switch`

### Set Password

```nix
services.dst-server = {
  # ... existing config ...
  clusterPassword = "your_password_here";
};
```

### Increase Player Limit

```nix
services.dst-server = {
  # ... existing config ...
  maxPlayers = 32;  # Default is 16
};
```

### Enable PvP

```nix
services.dst-server = {
  # ... existing config ...
  pvpEnabled = true;
  gameMode = "survival";  # Recommended for PvP
};
```

## Getting Help

- **Logs**: `journalctl -u dst-server-master.service -xe`
- **Service Status**: `systemctl status dst-server-master.service`
- **Configuration**: See [README.md](./README.md) for all options
- **Integration**: See [INTEGRATION.md](./INTEGRATION.md) for detailed flake setup

## Full Documentation

- [README.md](./README.md) - Complete documentation
- [INTEGRATION.md](./INTEGRATION.md) - How to integrate with your main flake
- [example-configuration.nix](./example-configuration.nix) - Configuration examples

## Maintenance

### View Logs
```bash
journalctl -u dst-server-master.service -f
```

### Restart Server
```bash
sudo systemctl restart dst-server-caves.service dst-server-master.service
```

### Update Server
Server auto-updates on restart by default. To disable:
```nix
services.dst-server.autoUpdate = false;
```

### Backup Save Files
```bash
sudo tar -czf dst-backup.tar.gz /var/lib/dst-server/DoNotStarveTogether/
```

Enjoy your server! 🎮

# Don't Starve Together Dedicated Server Setup Guide

Complete guide for setting up a Don't Starve Together dedicated server on Linux.

**Choose your approach:**
- **[NixOS](#nixos-setup)** - Modern, declarative, recommended (5 minutes)
- **[Debian/Ubuntu](#debianubuntu-setup)** - Traditional manual setup (20-30 minutes)

---

## NixOS Setup

**Recommended for NixOS users.** Everything is declarative and managed by your system configuration.

### Prerequisites
- NixOS system with flakes enabled
- Internet connection

### Quick Start (5 minutes)

#### 1. Get Cluster Token

Visit https://accounts.klei.com/account/game/servers?game=DontStarveTogether

1. Log in to your Klei account
2. Navigate to Games → Don't Starve Together → Game Servers
3. Click "Add New Server"
4. Copy the generated token
5. Save it securely:

```bash
sudo mkdir -p /var/lib/dst-server
echo "YOUR_TOKEN_HERE" | sudo tee /var/lib/dst-server/cluster_token.txt
sudo chmod 600 /var/lib/dst-server/cluster_token.txt
```

#### 2. Add Flake Input

Add to your system's `flake.nix` (typically in `/etc/nixos/` or `~/nixconf/`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # For published repository:
    dst-server.url = "github:yourusername/dst-server-nix";
    # Or for local development:
    # dst-server.url = "path:/home/boid/projects/dst-server/dst-server-nix";
  };

  outputs = { nixpkgs, dst-server, ... }: {
    nixosConfigurations.YOUR-HOSTNAME = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix  # or ./hosts/YOUR-HOSTNAME if using modular structure
        dst-server.nixosModules.default
        {
          services.dst-server = {
            enable = true;
            clusterName = "My NixOS Server";
            clusterDescription = "Powered by NixOS";
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

Replace `YOUR-HOSTNAME` with your actual hostname (check with `hostname` command).

#### 3. Apply Configuration

```bash
# Navigate to your system flake directory
cd ~/nixconf  # or wherever your flake.nix is located

# Update flake inputs to get latest dst-server changes
nix flake update dst-server

# Apply configuration
sudo nixos-rebuild switch --flake .#YOUR-HOSTNAME
```

Replace `YOUR-HOSTNAME` with your system's hostname. The first build will download the DST server binaries (~1GB, takes 3-5 minutes). Subsequent rebuilds only take seconds.

**What happens during the build:**
1. Creates `dst` user and group automatically
2. Creates required directories (`/var/lib/dst-server` and `/var/lib/dst-server-install`)
3. Downloads DST server via SteamCMD (on first run or when autoUpdate is enabled)
4. Generates configuration files (cluster.ini, server.ini) from your options
5. Copies cluster token file (must exist before rebuild)
6. Downloads and installs any configured mods
7. Creates and starts two systemd services: `dst-server-master.service` and `dst-server-caves.service`
8. Opens firewall ports if `openFirewall = true`

The Caves shard automatically depends on the Master shard, so they start in the correct order.

#### 4. Verify

```bash
# Check services
systemctl status dst-server-master.service
systemctl status dst-server-caves.service

# View logs
journalctl -u dst-server-master.service -f
```

#### Common Configurations

**Server with Mods:**
```nix
services.dst-server = {
  enable = true;
  clusterName = "Modded Server";
  clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  openFirewall = true;

  mods = [
    "350811795"  # Geometric Placement
    "378160973"  # Global Positions
    "666155465"  # Show Me
    "375859599"  # Health Info
    "362175979"  # Wormhole Marks
  ];
};
```

**PvP Server:**
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

**Password-Protected:**
```nix
services.dst-server = {
  enable = true;
  clusterName = "Private Server";
  clusterPassword = "secret123";
  clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  openFirewall = true;
};
```

**Custom Ports:**
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

### NixOS Benefits

- **Declarative**: Entire server config in one place
- **Reproducible**: Same config = same result, always
- **Atomic Updates**: Rollback if something breaks
- **No Manual Steps**: No user creation, package installation, or folder setup
- **Automatic Updates**: Server updates on service restart
- **Built-in Security**: systemd hardening, proper permissions, isolated service user
- **Automatic Dependency Handling**: Includes special libcurl-gnutls library required by DST (extracted from Debian package)

### Management Commands

```bash
# View logs (both shards)
journalctl -u dst-server-master.service -u dst-server-caves.service -f

# Restart server (caves depends on master, restart both)
systemctl restart dst-server-caves.service dst-server-master.service

# Stop server
systemctl stop dst-server-caves.service dst-server-master.service

# Update server
systemctl restart dst-server-master.service dst-server-caves.service

# Check status
systemctl status dst-server-master.service
```

### File Locations

- **Configs**: `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/`
- **Saves**: `/var/lib/dst-server/DoNotStarveTogether/Cluster_1/Master/save/`
- **Binaries**: `/var/lib/dst-server-install/`
- **Logs**: `journalctl -u dst-server-master.service`

For complete NixOS documentation, see [README.md](./README.md) and [QUICKSTART.md](./QUICKSTART.md).

---

## Debian/Ubuntu Setup

**For traditional Debian-based distributions.** Manual setup with systemd service.

### Tested Distributions
- Debian 10+
- Ubuntu 20.04+
- Ubuntu Server 20.04+
- PopOS 20.04+
- Other Debian-based distros

### Prerequisites
- 64-bit Linux system
- Sudo access
- 2GB+ RAM recommended
- 5GB+ free disk space

### Step 1: Create Dedicated User

For security, run the server as a separate user:

```bash
# Create user with home directory
sudo adduser steam

# Add to sudo group (for steamcmd)
sudo usermod -aG sudo steam

# Switch to steam user
sudo -u steam -s

# Move to steam home directory
cd /home/steam
```

**Important:** All following commands should run as the `steam` user.

### Step 2: Install Dependencies

#### Enable 32-bit Architecture

```bash
sudo dpkg --add-architecture i386
sudo apt-get update
```

#### Install SteamCMD

```bash
# Install steamcmd package
sudo apt install steamcmd

# Accept Steam license
# (will be prompted during installation)
```

#### Configure PATH

Add `/usr/games` to secure_path so steamcmd works everywhere:

```bash
# Edit sudoers
sudo visudo /etc/sudoers

# Find the line starting with "Defaults    secure_path"
# Add "/usr/games" to the end:
# Defaults    secure_path="/usr/local/sbin:..../usr/games"

# Save and exit
```

Re-login to steam user for PATH changes:

```bash
exit
sudo -u steam -s
cd /home/steam
```

### Step 3: Install DST Server

```bash
# Launch steamcmd
steamcmd

# In SteamCMD console:
force_install_dir /home/steam/steamapps/DST
login anonymous
app_update 343050 validate
quit
```

This downloads the DST dedicated server (~1GB, takes 5-10 minutes).

### Step 4: Create Directory Structure

DST requires a specific directory structure (hardcoded):

```bash
# Create Klei directories
mkdir -p ~/.klei/DoNotStarveTogether/MyDediServer/Master
mkdir -p ~/.klei/DoNotStarveTogether/MyDediServer/Caves
```

**Note:** The folder structure under `~/.klei/DoNotStarveTogether/` is mandatory. You can change `MyDediServer` to any cluster name.

### Step 5: Get Configuration Files

#### Obtain Cluster Token

**Required - server won't run without this.**

1. Visit https://accounts.klei.com/account/game/servers?game=DontStarveTogether
2. Log in to your Klei account
3. Navigate to "GAMES" tab → "Don't Starve Together" → "Game Servers"
4. Click "ADD NEW SERVER" (or "CONFIGURE" for existing)
5. Fill in server details:
   - Server name
   - Description
   - Password (optional)
   - Max players
   - Game mode
6. Click "Download Settings"
7. Extract the ZIP archive
8. Copy contents to `~/.klei/DoNotStarveTogether/MyDediServer/`

The ZIP contains:
- `cluster.ini` - Server settings
- `cluster_token.txt` - Authentication token (REQUIRED)
- `Master/server.ini` - Overworld shard config
- `Caves/server.ini` - Caves shard config

### Step 6: Configure Server Settings

Edit cluster configuration:

```bash
nano ~/.klei/DoNotStarveTogether/MyDediServer/cluster.ini
```

Common settings to review:

```ini
[GAMEPLAY]
game_mode = endless
max_players = 16
pvp = false
pause_when_empty = true

[NETWORK]
cluster_name = My Server Name
cluster_description = Server description here
cluster_password =

[MISC]
console_enabled = true

[SHARD]
shard_enabled = true
bind_ip = 127.0.0.1
master_ip = 127.0.0.1
master_port = 10998
cluster_key = defaultPass
```

**Optional - LAN Server:**

Add to `cluster.ini`:
```ini
[ACCOUNT]
dedicated_lan_server = true
```

### Step 7: Create Startup Script

Create a script to run both shards (Master + Caves):

```bash
cd /home/steam/steamapps/DST
nano run_dedicated_server.sh
```

Paste the following:

```bash
#!/bin/bash

# Configuration
steamcmd_dir="/usr/games"
install_dir="/home/steam/steamapps/DST"
cluster_name="MyDediServer"
dontstarve_dir="$HOME/.klei/DoNotStarveTogether"

# Function to check if running
check_for_file() {
    if [ ! -e "$1" ]; then
        echo "Error: File $1 does not exist!"
        exit 1
    fi
}

# Update server
cd "$steamcmd_dir" || exit
./steamcmd +force_install_dir "$install_dir" +login anonymous +app_update 343050 +quit

# Verify installation
check_for_file "$install_dir/bin64"

# Start Master Shard
cd "$install_dir/bin64" || exit
./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster "$cluster_name" -shard Master &

# Wait for Master to initialize
sleep 10

# Start Caves Shard
./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster "$cluster_name" -shard Caves &

# Keep script running
wait
```

Make executable:

```bash
chmod u+x run_dedicated_server.sh
```

### Step 8: Run Server

#### Option A: Manual Start

```bash
cd /home/steam/steamapps/DST
./run_dedicated_server.sh
```

Press `Ctrl+C` to stop.

#### Option B: Systemd Service (Recommended)

Create a systemd service for automatic start:

```bash
sudo nano /etc/systemd/system/dstserver.service
```

Paste the following:

```ini
[Unit]
Description=Don't Starve Together Dedicated Server
After=network.target

[Service]
Type=simple
User=steam
Group=steam
WorkingDirectory=/home/steam/steamapps/DST
ExecStart=/home/steam/steamapps/DST/run_dedicated_server.sh
Restart=on-failure
RestartSec=30s
TimeoutStopSec=720s

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable dstserver.service
sudo systemctl start dstserver.service
```

Check status:

```bash
sudo systemctl status dstserver.service
```

View logs:

```bash
sudo journalctl -u dstserver.service -f
```

### Step 9: Configure Firewall

Open required ports:

```bash
# UFW (Ubuntu/Debian default)
sudo ufw allow 10999/udp  # Master game port
sudo ufw allow 11000/udp  # Caves game port
sudo ufw allow 12346/udp  # Master Steam port
sudo ufw allow 12347/udp  # Caves Steam port

# Verify
sudo ufw status
```

Or with iptables:

```bash
sudo iptables -A INPUT -p udp --dport 10999 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 11000 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 12346 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 12347 -j ACCEPT
```

### Step 10: Verify Server

```bash
# Check logs
journalctl -u dstserver.service -n 50

# Look for:
# "Your Server GUID: KU_xxxxxxxx"
# "Sim paused"
# "Server registered..."

# Check ports
ss -tulpn | grep dontstarve
```

Your server should now be visible in the DST server browser.

---

## Adding Mods (Debian/Ubuntu)

### Step 1: Disable Validation

Remove `validate` from the update command to prevent overwriting mod configs:

```bash
nano /home/steam/steamapps/DST/run_dedicated_server.sh

# Change this line:
./steamcmd +force_install_dir "$install_dir" +login anonymous +app_update 343050 +quit

# Remove "validate" - should look like above
```

### Step 2: Configure Mods

Create mod setup file:

```bash
nano ~/.klei/DoNotStarveTogether/MyDediServer/Master/modoverrides.lua
```

Add mods (example):

```lua
return {
  ["workshop-350811795"] = { enabled = true },  -- Geometric Placement
  ["workshop-378160973"] = { enabled = true },  -- Global Positions
  ["workshop-666155465"] = { enabled = true },  -- Show Me
}
```

Create the same file for Caves:

```bash
cp ~/.klei/DoNotStarveTogether/MyDediServer/Master/modoverrides.lua \
   ~/.klei/DoNotStarveTogether/MyDediServer/Caves/modoverrides.lua
```

### Step 3: Setup Mod Download

```bash
nano /home/steam/steamapps/DST/mods/dedicated_server_mods_setup.lua
```

Add mod IDs:

```lua
ServerModSetup("350811795")  -- Geometric Placement
ServerModSetup("378160973")  -- Global Positions
ServerModSetup("666155465")  -- Show Me
```

### Step 4: Restart Server

```bash
sudo systemctl restart dstserver.service
```

Mods will download on first start (check logs).

---

## Comparison: NixOS vs Debian/Ubuntu

| Feature | NixOS | Debian/Ubuntu |
|---------|-------|---------------|
| **Setup Time** | 5 minutes | 20-30 minutes |
| **Approach** | Declarative config | Manual steps |
| **User Creation** | Automatic | Manual |
| **Package Install** | Automatic | Manual |
| **Service Setup** | Automatic | Manual |
| **Firewall** | Automatic (optional) | Manual |
| **Updates** | `nixos-rebuild switch` | Manual restart |
| **Rollback** | Built-in | Not available |
| **Reproducibility** | Perfect | Varies by system |
| **Mod Management** | Declarative list | Manual config files |
| **Config Drift** | Impossible | Possible |
| **Learning Curve** | Learn Nix | Familiar Linux |

---

## Common Issues

### Invalid Cluster Token
- Get fresh token from https://accounts.klei.com/account/game/servers?game=DontStarveTogether
- Ensure no extra whitespace in token file
- Check file permissions: `chmod 600 cluster_token.txt`

### Port Already in Use
- Check what's using the port: `ss -tulpn | grep 10999`
- Use custom ports in configuration
- Kill conflicting process if needed

### Server Not Visible in Browser
- Wait 2-3 minutes for registration
- Check firewall: ports 10999, 11000, 12346, 12347 UDP
- Verify services are running
- Check logs for errors

### Permission Errors (Debian/Ubuntu)
```bash
# Fix ownership
sudo chown -R steam:steam /home/steam/.klei
sudo chown -R steam:steam /home/steam/steamapps
```

### Mods Not Loading
- Verify mod IDs from Steam Workshop URLs
- Check `modoverrides.lua` syntax
- Ensure `dedicated_server_mods_setup.lua` exists
- Check logs: `journalctl -u dstserver.service | grep -i mod`

### Caves Won't Connect to Master
- Check shard ports in `cluster.ini`
- Verify `cluster_key` matches in both configs
- Ensure Master starts before Caves

---

## File Structure Reference

### NixOS
```
/var/lib/dst-server/
└── DoNotStarveTogether/
    └── Cluster_1/
        ├── cluster.ini
        ├── cluster_token.txt
        ├── Master/
        │   ├── server.ini
        │   └── save/
        ├── Caves/
        │   ├── server.ini
        │   └── save/
        └── mods/
            ├── dedicated_server_mods_setup.lua
            └── modsettings.lua
```

### Debian/Ubuntu
```
/home/steam/
├── .klei/
│   └── DoNotStarveTogether/
│       └── MyDediServer/
│           ├── cluster.ini
│           ├── cluster_token.txt
│           ├── Master/
│           │   ├── server.ini
│           │   ├── modoverrides.lua
│           │   └── save/
│           └── Caves/
│               ├── server.ini
│               ├── modoverrides.lua
│               └── save/
└── steamapps/
    └── DST/
        ├── bin64/
        │   └── dontstarve_dedicated_server_nullrenderer_x64
        ├── mods/
        │   └── dedicated_server_mods_setup.lua
        └── run_dedicated_server.sh
```

---

## Management Commands Reference

### NixOS

```bash
# View logs
journalctl -u dst-server-master.service -f
journalctl -u dst-server-caves.service -f

# Restart
systemctl restart dst-server-caves.service dst-server-master.service

# Stop
systemctl stop dst-server-caves.service dst-server-master.service

# Start
systemctl start dst-server-master.service dst-server-caves.service

# Status
systemctl status dst-server-master.service

# Update config
# Edit your configuration.nix, then:
sudo nixos-rebuild switch --flake .#heron
```

### Debian/Ubuntu

```bash
# View logs
journalctl -u dstserver.service -f

# Restart
sudo systemctl restart dstserver.service

# Stop
sudo systemctl stop dstserver.service

# Start
sudo systemctl start dstserver.service

# Status
sudo systemctl status dstserver.service

# Manual run (debugging)
cd /home/steam/steamapps/DST
./run_dedicated_server.sh
```

---

## Resources

### Official Documentation
- [Klei Forums - Dedicated Server Guide](https://forums.kleientertainment.com/forums/topic/64212-dedicated-server-quick-setup-guide-windows/)
- [Steam - DST Dedicated Server](https://steamdb.info/app/343050/)
- [SteamCMD Wiki](https://developer.valvesoftware.com/wiki/SteamCMD)

### Mod Resources
- [Steam Workshop](https://steamcommunity.com/app/322330/workshop/)
- [Mod Configuration Guide](https://forums.kleientertainment.com/forums/topic/59174-guide-how-to-installconfigure-and-update-mods-on-dedicated-server/)

### This Repository
- [README.md](./README.md) - Complete NixOS documentation
- [QUICKSTART.md](./QUICKSTART.md) - NixOS quick start
- [INTEGRATION.md](./INTEGRATION.md) - Flake integration guide
- [example-configuration.nix](./example-configuration.nix) - Configuration examples

---

## Credits

- Original Debian guide by community contributors on Klei forums
- NixOS module based on [Jamesits/docker-dst-server](https://github.com/Jamesits/docker-dst-server)
- Don't Starve Together by [Klei Entertainment](https://www.klei.com/)

## License

Same as the original docker-dst-server project.

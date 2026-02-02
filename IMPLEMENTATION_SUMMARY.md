# Implementation Summary

This document summarizes the NixOS flake implementation for the Don't Starve Together server.

## What Was Implemented

A complete NixOS module that provides native DST server functionality without Docker, based on the existing `docker-dst-server` setup.

## File Structure

```
/home/boid/projects/dst-server/nix/
├── flake.nix                          # Main flake entry point
├── flake.lock                         # Flake lock file
├── modules/
│   └── dst-server.nix                 # NixOS module (services.dst-server)
├── packages/
│   └── dst-server-scripts.nix         # Helper scripts package
├── config-templates/
│   ├── cluster.ini.nix                # Templated cluster config
│   ├── server-master.ini.nix          # Master shard config template
│   ├── server-caves.ini.nix           # Caves shard config template
│   ├── worldgenoverride-master.lua    # Master world generation
│   ├── worldgenoverride-caves.lua     # Caves world generation
│   ├── agreements.ini                 # EULA
│   └── mods/
│       └── modsettings.lua            # Mod settings
├── README.md                          # Complete documentation
├── INTEGRATION.md                     # Integration guide for main flake
├── QUICKSTART.md                      # Quick start guide
├── example-configuration.nix          # Example configurations
└── .gitignore                         # Git ignore rules
```

## Key Features Implemented

### 1. NixOS Module (`modules/dst-server.nix`)

**Configuration Options:**
- Server identity: `clusterName`, `clusterDescription`, `clusterPassword`
- Gameplay: `maxPlayers`, `gameMode`, `pvpEnabled`, `pauseWhenEmpty`
- Ports: `master`, `caves`, `masterSteam`, `cavesSteam`, `shardMaster`
- System: `dataDir`, `serverInstallDir`, `user`, `group`, `architecture`
- Features: `autoUpdate`, `openFirewall`, `mods`
- Advanced: `extraClusterConfig`, `extraMasterConfig`, `extraCavesConfig`

**Systemd Services:**
- `dst-server-master.service` - Overworld shard
- `dst-server-caves.service` - Caves shard (depends on master)

**Features:**
- Automatic directory structure creation
- Cluster token handling (with newline removal)
- Non-destructive config initialization
- Automatic server updates via SteamCMD
- Mod installation and management
- Proper permissions and ownership
- Security hardening (NoNewPrivileges, PrivateTmp, etc.)

### 2. Configuration Templates

**Nix Templates (with string interpolation):**
- `cluster.ini.nix` - Cluster-wide settings
- `server-master.ini.nix` - Master shard settings
- `server-caves.ini.nix` - Caves shard settings

**Static Files (copied as-is):**
- `worldgenoverride-master.lua` - World generation for overworld
- `worldgenoverride-caves.lua` - World generation for caves
- `modsettings.lua` - Mod configuration
- `agreements.ini` - EULA acceptance

### 3. Helper Scripts Package

**Scripts provided:**
- `dst-generate-token` - Instructions for obtaining cluster token
- `dst-logs` - View service logs (master/caves/all)
- `dst-status` - Check service status
- `dst-restart` - Restart services

### 4. Flake Outputs

**NixOS Modules:**
- `nixosModules.default` - Main module
- `nixosModules.dst-server` - Alias

**Packages:**
- `packages.<system>.dst-server-scripts` - Helper scripts
- `packages.<system>.default` - Alias

**Dev Shell:**
- `devShells.<system>.default` - Development environment with steamcmd, nixpkgs-fmt, nil

**Apps:**
- `apps.<system>.generate-token` - Token generation instructions

## Docker → Nix Translation

| Docker Component | Nix Equivalent | Notes |
|------------------|----------------|-------|
| Supervisor | systemd | Native process management |
| entrypoint.sh | systemd preStart | Initialization logic |
| Environment variables | Nix options | Declarative configuration |
| Volume mounts | StateDirectory | Automatic directory creation |
| Docker networking | Firewall rules | Optional automatic configuration |
| Container restart | systemd Restart | on-failure with 30s delay |
| stopwaitsecs | TimeoutStopSec | 720s graceful shutdown |
| depends_on | systemd requires/after | Caves depends on Master |

## Initialization Logic (preStart)

The systemd `preStart` script performs the following:

1. Create directory structure: `DoNotStarveTogether/Cluster_1/{Master,Caves,mods}`
2. Copy cluster token from `cfg.clusterTokenFile` and remove trailing newline
3. Copy default configs if they don't exist (non-destructive):
   - `cluster.ini`
   - `Master/server.ini`
   - `Caves/server.ini`
   - `Master/worldgenoverride.lua`
   - `Caves/worldgenoverride.lua`
   - `mods/modsettings.lua`
   - `Agreements/agreements.ini`
4. Generate `dedicated_server_mods_setup.lua` from `cfg.mods` list
5. Update server via SteamCMD (if `autoUpdate = true`)
6. Create mods symlink: `${serverInstallDir}/mods → ${dataDir}/.../mods`
7. Update mods using DST server's `-only_update_server_mods` flag
8. Fix permissions: `chown -R dst:dst ${dataDir}`

## Configuration Layers

1. **Nix Options** → Generate templated configs
2. **Generated Configs** → Copied to dataDir on first run
3. **User Manual Edits** → Preserved across restarts

This allows both declarative (Nix) and imperative (manual file edits) configuration styles.

## Security Features

- Dedicated system user (`dst`) and group
- No new privileges (`NoNewPrivileges = true`)
- Private tmp directory (`PrivateTmp = true`)
- Protected system files (`ProtectSystem = "strict"`)
- Protected home directories (`ProtectHome = true`)
- Restricted write access (`ReadWritePaths = [ dataDir serverInstallDir ]`)

## Architecture Support

Supports both x86 (32-bit) and x64 (64-bit) server binaries:
- x64: `bin64/dontstarve_dedicated_server_nullrenderer_x64`
- x86: `bin/dontstarve_dedicated_server_nullrenderer`

## Default Values

| Option | Default | Rationale |
|--------|---------|-----------|
| `maxPlayers` | 16 | Reasonable default |
| `gameMode` | "endless" | Most popular mode |
| `pvpEnabled` | false | Safer default |
| `pauseWhenEmpty` | true | Save resources |
| `ports.master` | 10999 | DST standard |
| `ports.caves` | 11000 | DST standard |
| `ports.shardMaster` | 10998 | Inter-shard comm |
| `openFirewall` | false | Explicit opt-in |
| `autoUpdate` | true | Keep server current |
| `architecture` | "x64" | Modern systems |

## Verification

The implementation has been verified:
- ✅ Flake syntax check: `nix flake check` passes
- ✅ Flake structure: Outputs include modules, packages, devShells, apps
- ✅ Module structure: Follows NixOS conventions
- ✅ Config templates: Use proper string interpolation
- ✅ Static files: Copied from docker-dst-server

## Usage

### Basic Setup

1. Get cluster token from Klei
2. Add flake as input to main system flake
3. Import `nixosModules.default`
4. Configure `services.dst-server`
5. Run `nixos-rebuild switch`

### Example Configuration

```nix
services.dst-server = {
  enable = true;
  clusterName = "My NixOS Server";
  clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
  maxPlayers = 24;
  openFirewall = true;
  mods = [ "350811795" ];
};
```

## Documentation

- **README.md** - Complete feature documentation, configuration reference
- **QUICKSTART.md** - 5-minute setup guide
- **INTEGRATION.md** - How to add to existing NixOS flake
- **example-configuration.nix** - Various configuration examples

## Testing Recommendations

1. **Build check**: `nix flake check`
2. **Show outputs**: `nix flake show`
3. **Test build**: `nixos-rebuild build --flake .#`
4. **VM test**: `nixos-rebuild build-vm --flake .#`
5. **Deploy**: `nixos-rebuild switch --flake .#`
6. **Verify services**: `systemctl status dst-server-{master,caves}.service`
7. **Check logs**: `journalctl -u dst-server-master.service -f`
8. **Test connectivity**: Join from DST client
9. **Test mods**: Add mod, restart, verify in logs
10. **Test updates**: Set `autoUpdate = true`, restart, check logs

## Next Steps

To use this implementation:

1. Copy the cluster token setup from QUICKSTART.md
2. Follow INTEGRATION.md to add to your main flake
3. Configure services.dst-server as needed
4. Run nixos-rebuild switch
5. Monitor logs and test connectivity

## Notes

- Coexists with docker-dst-server (separate directories)
- No Docker dependency
- Native systemd management
- Declarative configuration
- Automatic updates
- Mod support
- Security hardening
- Firewall integration

## Compatibility

- Tested with: NixOS unstable
- Architecture: x86_64-linux (also supports aarch64-linux, *-darwin)
- DST Server: Latest version (auto-updated)
- SteamCMD: From nixpkgs

## Credits

Implementation based on [Jamesits/docker-dst-server](https://github.com/Jamesits/docker-dst-server)

# DST Server Testing Results

## Status: FULLY OPERATIONAL ✓

All issues have been successfully resolved. The Don't Starve Together dedicated server is now running with both Master and Caves shards operational.

## Issues Found and Fixed

### 1. Missing Library Dependencies

The DST server binary requires several specific library versions that aren't available in modern NixOS. Fixed by adding Debian packages and additional libraries to LD_LIBRARY_PATH:

- **libssh2** - Added `libssh2` package to library path
- **libnettle.so.6** - Extracted from Debian `libnettle6_3.4.1-1` package (modern NixOS has version 8)
- **libgssapi_krb5.so.2** - Added `krb5` package to library path
- **libcom_err.so.2** - Added `e2fsprogs` package to library path
- **libldap_r-2.4.so.2** - Extracted from Debian `libldap-2.4-2_2.4.47` package (modern NixOS has version 2.6)
- **libsasl2.so.2** - Extracted from Debian `libsasl2-2_2.1.27` package (modern NixOS has version 3)

### 2. Directory Permissions Issue

**Problem:** User home directory created with 0700 permissions (not readable by others)
**Cause:** `createHome = true` in user configuration causes systemd to create home with restrictive permissions
**Fix:** Set `createHome = false` and let tmpfiles.rules create directories with 0755 permissions

### 3. Incorrect Hash for libnettle6

**Problem:** Initial hash was incorrect, causing build to fail silently
**Fix:** Updated to correct hash `sha256-WjhMdzrmiwx5BezAq/XkWSV5S2eWdIZtd4PYh4b/sNI=`

### 4. Working Directory Issue

**Problem:** Server failed to load `scripts/main.lua` with error "DoLuaFile Could not load lua file scripts/main.lua"
**Cause:** DST server expects to run from the `bin64` directory to correctly locate `../data` directory containing game scripts
**Fix:** Modified wrapper script to `cd ${cfg.serverInstallDir}/bin64` before executing the server binary

## Testing Process

Tested using:
```bash
cd ~/nixconf
nix flake update dst-server
sudo nixos-rebuild switch --flake .#heron
```

Each iteration revealed a new missing library as the server attempted to start.

## Module Changes

### Added Debian Package Extractions

```nix
libnettle6 = pkgs.stdenv.mkDerivation {
  pname = "libnettle6";
  version = "3.4.1";
  src = pkgs.fetchurl {
    url = "http://snapshot.debian.org/archive/debian/20190323T031635Z/pool/main/n/nettle/libnettle6_3.4.1-1_amd64.deb";
    sha256 = "sha256-WjhMdzrmiwx5BezAq/XkWSV5S2eWdIZtd4PYh4b/sNI=";
  };
  # ... extraction logic
};

libldap24 = pkgs.stdenv.mkDerivation {
  pname = "libldap-2.4";
  version = "2.4.47";
  src = pkgs.fetchurl {
    url = "http://snapshot.debian.org/archive/debian/20190323T031635Z/pool/main/o/openldap/libldap-2.4-2_2.4.47%2Bdfsg-3_amd64.deb";
    sha256 = "sha256-Sk0JCEtEm5WWuRufJ8CGp2VBCUjaB5/RURwBHJFanBw=";
  };
  # ... extraction logic
};

libsasl2 = pkgs.stdenv.mkDerivation {
  pname = "libsasl2-2";
  version = "2.1.27";
  src = pkgs.fetchurl {
    url = "http://snapshot.debian.org/archive/debian/20190323T031635Z/pool/main/c/cyrus-sasl2/libsasl2-2_2.1.27%2Bdfsg-1_amd64.deb";
    sha256 = "sha256-1YdvsZPEdqIiChs243eWLc0Cc+P4oupC6bWZ/0gOtlU=";
  };
  # ... extraction logic
};
```

### Updated Wrapper Script

```nix
wrappedServerBin = pkgs.writeShellScript "dst-server-wrapper" ''
  export LD_LIBRARY_PATH="${libcurlGnutls}/lib:${libnettle6}/lib:${libldap24}/lib:${libsasl2}/lib:${lib.makeLibraryPath (with pkgs; [
    glibc stdenv.cc.cc.lib zlib gnutls libidn2 nghttp2 libpsl rtmpdump libssh2 krb5 e2fsprogs
  ])}"
  cd ${cfg.serverInstallDir}/bin64
  exec ./dontstarve_dedicated_server_nullrenderer_x64 "$@"
'';
```

The wrapper now:
- Sets LD_LIBRARY_PATH with all required libraries (modern NixOS and old Debian packages)
- Changes to bin64 directory before execution (required for server to find game data)
- Executes the server binary directly from bin64

### Fixed User Creation

```nix
users.users.${cfg.user} = {
  isSystemUser = true;
  group = cfg.group;
  home = cfg.dataDir;
  createHome = false;  # Let tmpfiles.rules create with correct permissions (0755)
  description = "Don't Starve Together server user";
};
```

## Services Created

- **dst-server-master.service** - Overworld shard
- **dst-server-caves.service** - Caves shard (depends on master)

Both services:
- Auto-update on start (via steamcmd in preStart)
- Run as dedicated `dst` user
- Include systemd hardening (NoNewPrivileges, PrivateTmp, ProtectSystem)
- Restart on failure with 30s delay

## Verification Commands

```bash
# Check service status
systemctl status dst-server-master.service
systemctl status dst-server-caves.service

# View logs
journalctl -u dst-server-master.service -f

# Check ports
ss -tulpn | grep dontstarve

# Verify libraries
cat /nix/store/*-dst-server-wrapper | grep LD_LIBRARY_PATH
```

## Final Status

**SERVER FULLY OPERATIONAL** ✓✓✓

The server now successfully:
- Loads all required libraries (both NixOS and Debian packages)
- Starts the DST server binary from correct working directory
- Retrieves the cluster token
- Loads all Lua game scripts
- Generates world maps for both Master and Caves shards
- Establishes inter-shard communication
- Listens on all configured network ports
- Both shards running and synchronized

### Service Status
```
dst-server-master.service: Active (running)
  Memory: 1.1GB, Tasks: 17
  Validating portals and syncing world settings with caves shard

dst-server-caves.service: Active (running)
  Memory: 967MB, Tasks: 17
  Connected to master shard, secondary shard LUA ready
  Sim paused (waiting for players - pauseWhenEmpty enabled)
```

### Network Ports Listening
```
UDP 10998 (127.0.0.1) - Shard master communication (localhost only)
UDP 10999 (0.0.0.0)   - Master game port
UDP 11000 (0.0.0.0)   - Caves game port
UDP 12346 (0.0.0.0)   - Master Steam port
UDP 12347 (0.0.0.0)   - Caves Steam port
```

### Sample Logs
```
[00:00:12]: Done forest map gen!
[00:00:12]: Generation complete, injecting world entities.
[00:00:12]: WorldSim::SimThread::Main() complete
[00:00:12]: Serializing world: session/749DFB4545F0404F/0000000002
[00:00:16]: [Shard] secondary shard LUA is now ready!
[00:00:16]: Sim paused
```

## Setup Requirements

- Cluster token file must exist at path specified by `clusterTokenFile` option
- First startup downloads ~1GB server files (takes 3-5 minutes)
- Each service restart triggers validation (takes 1-2 minutes)
- Firewall ports must be opened if `openFirewall = false` (default)

## SETUP_GUIDE.md Updates

The guide now includes:
- Clarification about running commands from nixconf directory
- Explanation of what happens during build
- Note about hostname placeholders
- Both GitHub URL and local path options for flake input
- Description of automatic dependency handling including special Debian libraries

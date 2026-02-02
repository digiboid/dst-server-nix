# Integrating DST Server into Your Main NixOS Flake

This guide shows how to add the DST server module as an input to your existing NixOS flake configuration.

## Understanding the Setup

You have created a **standalone flake** at `/home/boid/projects/dst-server/nix/`. This flake:
- Provides a NixOS module (`nixosModules.default`)
- Can be imported as an input into your main system flake
- Allows you to use `services.dst-server` in your NixOS configuration

## Integration Steps

### Option 1: Using Path Input (Local Development)

If your main NixOS flake is at `/home/boid/nixconf/` (or similar), edit `/home/boid/nixconf/flake.nix`:

```nix
{
  description = "My NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add DST server as a local path input
    dst-server.url = "path:/home/boid/projects/dst-server/nix";
    # Other inputs...
  };

  outputs = { self, nixpkgs, dst-server, ... }: {
    nixosConfigurations = {
      # Your hostname here (e.g., "myserver", "nixos", etc.)
      myserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Your existing modules
          ./configuration.nix
          ./hardware-configuration.nix

          # Add the DST server module
          dst-server.nixosModules.default

          # Configure DST server inline or in configuration.nix
          {
            services.dst-server = {
              enable = true;
              clusterName = "My NixOS Server";
              clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
              maxPlayers = 16;
              openFirewall = true;
            };
          }
        ];
      };
    };
  };
}
```

### Option 2: Using Git Input

If you want to version the DST server configuration with git:

```bash
cd /home/boid/projects/dst-server/nix
git init
git add .
git commit -m "Initial DST server flake"
```

Then in your main flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Use git+file URL
    dst-server.url = "git+file:///home/boid/projects/dst-server/nix";
  };
  # ... rest same as above
}
```

### Option 3: Configuration in Separate File

For cleaner organization, put DST config in a separate file:

**`/home/boid/nixconf/flake.nix`:**
```nix
{
  description = "My NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "path:/home/boid/projects/dst-server/nix";
  };

  outputs = { self, nixpkgs, dst-server, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        dst-server.nixosModules.default
        ./dst-server.nix  # DST config in separate file
      ];
    };
  };
}
```

**`/home/boid/nixconf/dst-server.nix`:**
```nix
{ config, pkgs, ... }:

{
  services.dst-server = {
    enable = true;
    clusterName = "My DST Server";
    clusterDescription = "Running on NixOS!";
    clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";

    maxPlayers = 24;
    gameMode = "endless";
    pvpEnabled = false;
    pauseWhenEmpty = true;

    openFirewall = true;
    autoUpdate = true;

    mods = [
      "350811795"  # Geometric Placement
      "378160973"  # Global Positions
    ];
  };
}
```

## Traditional NixOS Configuration (No Flakes)

If you're **not** using flakes and have a traditional `/etc/nixos/configuration.nix`:

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Import the DST server module directly
    /home/boid/projects/dst-server/nix/modules/dst-server.nix
  ];

  # ... your other config ...

  services.dst-server = {
    enable = true;
    clusterName = "My DST Server";
    clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
    openFirewall = true;
  };
}
```

## Applying the Configuration

After adding the DST server to your flake/configuration:

```bash
# If using flakes (from your main flake directory)
cd /home/boid/nixconf
sudo nixos-rebuild switch --flake .#myserver

# If using traditional configuration
sudo nixos-rebuild switch
```

## Complete Example: Main Flake Structure

Here's what a typical main flake directory might look like:

```
/home/boid/nixconf/
├── flake.nix                    # Main flake (imports dst-server)
├── flake.lock                   # Lock file
├── configuration.nix            # Main system config
├── hardware-configuration.nix   # Hardware config
├── dst-server.nix              # DST server config (optional)
└── ...

/home/boid/projects/dst-server/nix/
├── flake.nix                    # DST flake (imported as input)
├── flake.lock
├── modules/
│   └── dst-server.nix
└── ...
```

## Updating the DST Server Flake

If you make changes to the DST server flake, update your main flake:

```bash
cd /home/boid/nixconf
nix flake update dst-server
sudo nixos-rebuild switch --flake .#
```

## Testing Before Deployment

Test the configuration without activating it:

```bash
# Build without activating
nixos-rebuild build --flake .#myserver

# Test in a VM
nixos-rebuild build-vm --flake .#myserver
./result/bin/run-*-vm
```

## Troubleshooting

### "dst-server" input not found

Make sure:
1. The DST server flake exists at the specified path
2. The path in `inputs.dst-server.url` is correct
3. You've run `nix flake update` after adding the input

### Module not found

Ensure you've added both:
1. The input: `dst-server.url = "path:..."`
2. The module: `dst-server.nixosModules.default` in your modules list

### Permission errors

The cluster token file must be readable by the dst user:
```bash
sudo mkdir -p /var/lib/dst-server
sudo chown dst:dst /var/lib/dst-server
echo "YOUR_TOKEN" | sudo tee /var/lib/dst-server/cluster_token.txt
sudo chmod 600 /var/lib/dst-server/cluster_token.txt
sudo chown dst:dst /var/lib/dst-server/cluster_token.txt
```

## Next Steps

1. **Get cluster token**: Visit https://accounts.klei.com/account/game/servers?game=DontStarveTogether
2. **Add to your flake**: Follow one of the options above
3. **Configure**: Set `clusterName`, `maxPlayers`, etc.
4. **Deploy**: Run `nixos-rebuild switch`
5. **Verify**: Check `systemctl status dst-server-master.service`

For detailed configuration options, see [README.md](./README.md).

# Using the GitHub Repository

Your DST server flake is now published on GitHub! 🎉

**Repository**: https://github.com/digiboid/dst-server-nix

## Using in Your NixOS Configuration

### Option 1: Latest Main Branch (Recommended for Development)

In your main flake (e.g., `/home/boid/nixconf/flake.nix`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "github:digiboid/dst-server-nix";
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

### Option 2: Pinned to Stable Release (Recommended for Production)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "github:digiboid/dst-server-nix/v1.0.0";  # Pin to v1.0.0
  };
  # ... rest same as above
}
```

### Option 3: Using Specific Commit

```nix
{
  inputs = {
    dst-server.url = "github:digiboid/dst-server-nix/3e0b96f";  # Pin to specific commit
  };
  # ... rest same as above
}
```

## Updating the Flake

### Update to Latest

```bash
cd /home/boid/nixconf
nix flake update dst-server
sudo nixos-rebuild switch --flake .#
```

### Update to Specific Version

Edit your flake.nix to change the version:
```nix
dst-server.url = "github:digiboid/dst-server-nix/v1.0.1";
```

Then:
```bash
nix flake update dst-server
sudo nixos-rebuild switch --flake .#
```

## Making Changes and Releasing

### 1. Make Changes Locally

```bash
cd /home/boid/projects/dst-server/nix
# Edit files...
git add .
git commit -m "Description of changes"
git push
```

### 2. Create New Release

```bash
git tag -a v1.0.1 -m "Release v1.0.1 - Description"
git push origin v1.0.1
```

### 3. Users Update

Users update with:
```bash
nix flake update dst-server
```

Or pin to new version:
```nix
dst-server.url = "github:digiboid/dst-server-nix/v1.0.1";
```

## Testing Changes Before Release

Test locally before pushing:

```bash
cd /home/boid/projects/dst-server/nix
# Make changes...
git add .
git commit -m "Test changes"

# Test in your system without pushing
cd /home/boid/nixconf
# Edit flake.nix temporarily:
# dst-server.url = "path:/home/boid/projects/dst-server/nix";
nix flake update dst-server
sudo nixos-rebuild switch --flake .#

# If good, push to GitHub
cd /home/boid/projects/dst-server/nix
git push
```

## Repository Structure on GitHub

Your repository now contains:
- ✅ Complete NixOS module
- ✅ Configuration templates
- ✅ Helper scripts
- ✅ Full documentation
- ✅ Version v1.0.0 tagged

## Sharing Your Flake

Others can now use your flake by adding to their configuration:

```nix
{
  inputs.dst-server.url = "github:digiboid/dst-server-nix";
  # ...
}
```

## GitHub Features You Can Use

### Issues
Track bugs and feature requests at:
https://github.com/digiboid/dst-server-nix/issues

### Releases
Create release notes at:
https://github.com/digiboid/dst-server-nix/releases

### Topics
Add repository topics for discoverability:
- `nixos`
- `nix-flake`
- `dont-starve-together`
- `gaming-server`

### Description
Update at: https://github.com/digiboid/dst-server-nix/settings

## Cleanup

You can now delete the old directory:

```bash
rm -rf /home/boid/projects/dst-server/nix-old
```

## Quick Reference

| Action | Command |
|--------|---------|
| Clone locally | `git clone git@github.com:digiboid/dst-server-nix.git` |
| Check flake | `nix flake check` |
| Show outputs | `nix flake show github:digiboid/dst-server-nix` |
| Update in system | `nix flake update dst-server` |
| View on GitHub | https://github.com/digiboid/dst-server-nix |
| Current version | v1.0.0 |

## Next Steps

1. ✅ Repository is live on GitHub
2. ✅ Version v1.0.0 is tagged
3. → Update your main flake to use `github:digiboid/dst-server-nix`
4. → Test the deployment
5. → Share with others!

Congratulations! Your NixOS DST server flake is now publicly available! 🚀

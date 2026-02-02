# GitHub Setup Instructions

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `dst-server-nix` (or your preferred name)
3. Description: `NixOS flake for Don't Starve Together dedicated server`
4. Choose **Public** (recommended) or **Private**
5. **Do NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

## Step 2: Push to GitHub

GitHub will show you commands. Use these:

```bash
cd /home/boid/projects/dst-server/nix

# Add remote (replace YOUR-USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR-USERNAME/dst-server-nix.git

# Or if you use SSH:
# git remote add origin git@github.com:YOUR-USERNAME/dst-server-nix.git

# Push to GitHub
git push -u origin main
```

## Step 3: Verify

Visit your repository at: `https://github.com/YOUR-USERNAME/dst-server-nix`

You should see all files including README.md displayed.

## Step 4: Update Your Main Flake

Once pushed to GitHub, update your main NixOS flake to use the GitHub URL:

### Before (local path):
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "path:/home/boid/projects/dst-server/nix";
  };
}
```

### After (GitHub):
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dst-server.url = "github:YOUR-USERNAME/dst-server-nix";
    # Or pin to specific version:
    # dst-server.url = "github:YOUR-USERNAME/dst-server-nix/v1.0.0";
  };
}
```

## Step 5: Update Flake Lock

After changing to GitHub URL:

```bash
cd /home/boid/nixconf  # Your main flake directory
nix flake update dst-server
sudo nixos-rebuild switch --flake .#
```

## Benefits of GitHub Hosting

1. **Version control**: Tag releases for stable versions
2. **Easy updates**: `nix flake update` pulls latest changes
3. **Sharing**: Others can use your flake
4. **Collaboration**: Accept PRs for improvements
5. **Automatic**: Flakes cache GitHub repos efficiently

## Creating Releases

When you want to publish a stable version:

```bash
cd /home/boid/projects/dst-server/nix
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

Users can then pin to this version:
```nix
dst-server.url = "github:YOUR-USERNAME/dst-server-nix/v1.0.0";
```

## Making Updates

When you make changes:

```bash
cd /home/boid/projects/dst-server/nix

# Make your changes
# ...

# Commit
git add .
git commit -m "Description of changes"
git push

# Optionally tag a new version
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

Users can update with:
```bash
nix flake update dst-server
```

## Recommended GitHub Repository Settings

### Topics
Add these topics to help others find your repo:
- `nixos`
- `nix`
- `flake`
- `dont-starve-together`
- `dst`
- `gaming`
- `dedicated-server`

### License
Consider adding a license (e.g., MIT) if you want others to use it.

### Repository Description
"NixOS flake for running Don't Starve Together dedicated server natively without Docker"

## Alternative: Using Git+File URL

If you don't want to use GitHub, you can use a local git URL in your main flake:

```nix
dst-server.url = "git+file:///home/boid/projects/dst-server/nix";
```

This still benefits from git's version tracking but doesn't require GitHub.

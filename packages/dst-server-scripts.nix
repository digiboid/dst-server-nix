{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "dst-server-scripts";
  version = "1.0.0";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin

    # dst-generate-token: Instructions for obtaining cluster token
    cat > $out/bin/dst-generate-token <<'EOF'
#!/usr/bin/env bash
cat <<'INSTRUCTIONS'
To generate a cluster token for your Don't Starve Together server:

1. Visit: https://accounts.klei.com/account/game/servers?game=DontStarveTogether
2. Log in with your Klei account
3. Click "Add New Server"
4. Give your server a name
5. Copy the generated token
6. Save it to a file (e.g., /var/lib/dst-server/cluster_token.txt)
7. Configure your NixOS system with:

   services.dst-server = {
     enable = true;
     clusterTokenFile = "/var/lib/dst-server/cluster_token.txt";
     # ... other options ...
   };

The token file should contain only the token string with no trailing newline.
INSTRUCTIONS
EOF
    chmod +x $out/bin/dst-generate-token

    # dst-logs: View systemd logs for both shards
    cat > $out/bin/dst-logs <<'EOF'
#!/usr/bin/env bash
set -e

SHARD="''${1:-}"

if [ -z "$SHARD" ]; then
  echo "Usage: dst-logs [master|caves|all]"
  echo ""
  echo "View logs for DST server shards"
  echo ""
  echo "Options:"
  echo "  master  - Show logs for master (overworld) shard"
  echo "  caves   - Show logs for caves shard"
  echo "  all     - Show logs for both shards (default)"
  exit 1
fi

case "$SHARD" in
  master)
    exec ${pkgs.systemd}/bin/journalctl -u dst-server-master.service -f
    ;;
  caves)
    exec ${pkgs.systemd}/bin/journalctl -u dst-server-caves.service -f
    ;;
  all|*)
    exec ${pkgs.systemd}/bin/journalctl -u dst-server-master.service -u dst-server-caves.service -f
    ;;
esac
EOF
    chmod +x $out/bin/dst-logs

    # dst-status: Check status of both services
    cat > $out/bin/dst-status <<'EOF'
#!/usr/bin/env bash
set -e

echo "=== Don't Starve Together Server Status ==="
echo ""
echo "Master Shard:"
${pkgs.systemd}/bin/systemctl status dst-server-master.service --no-pager || true
echo ""
echo "Caves Shard:"
${pkgs.systemd}/bin/systemctl status dst-server-caves.service --no-pager || true
EOF
    chmod +x $out/bin/dst-status

    # dst-restart: Restart both services
    cat > $out/bin/dst-restart <<'EOF'
#!/usr/bin/env bash
set -e

SHARD="''${1:-all}"

case "$SHARD" in
  master)
    echo "Restarting master shard..."
    sudo systemctl restart dst-server-master.service
    ;;
  caves)
    echo "Restarting caves shard..."
    sudo systemctl restart dst-server-caves.service
    ;;
  all)
    echo "Restarting both shards..."
    sudo systemctl restart dst-server-caves.service dst-server-master.service
    ;;
  *)
    echo "Usage: dst-restart [master|caves|all]"
    exit 1
    ;;
esac

echo "Done!"
EOF
    chmod +x $out/bin/dst-restart
  '';

  meta = with pkgs.lib; {
    description = "Helper scripts for managing Don't Starve Together dedicated server";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

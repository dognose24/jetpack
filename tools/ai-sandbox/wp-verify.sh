#!/usr/bin/env bash
# Manage the wp-verify WordPress stack for premium-analytics UI verification.
#
# Usage (from anywhere inside the jetpack repo, or from inside jetpack-ai-sandbox):
#   tools/ai-sandbox/wp-verify.sh up    # start WordPress stack + sandbox with Docker socket
#   tools/ai-sandbox/wp-verify.sh down  # stop everything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect JETPACK_HOST_PATH — the jetpack root on the HOST filesystem.
# Docker bind mounts are resolved by the host daemon, so we must pass the host path
# even when running this script from inside the sandbox container.
if [ -f /.dockerenv ]; then
  # Inside sandbox: ask Docker where the jetpack bind mount originates on the host.
  JETPACK_HOST_PATH=$(docker inspect jetpack-ai-sandbox \
    --format '{{range .Mounts}}{{if eq .Destination "/home/dev/jetpack"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)
  if [ -z "$JETPACK_HOST_PATH" ]; then
    echo "Error: could not detect host jetpack path — is the container named jetpack-ai-sandbox?" >&2
    exit 1
  fi
else
  # On host: resolve relative to this script's location (tools/ai-sandbox → repo root).
  JETPACK_HOST_PATH="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
export JETPACK_HOST_PATH

COMPOSE=(
  docker compose
  -f "$SCRIPT_DIR/docker-compose.yml"
  -f "$SCRIPT_DIR/docker-compose.wp-verify.yml"
  --project-directory "$SCRIPT_DIR"
)

case "${1:-up}" in
  up)
    echo "JETPACK_HOST_PATH=$JETPACK_HOST_PATH"
    if [ -f /.dockerenv ]; then
      # Inside sandbox: jetpack-ai is already running; only start the WP services.
      "${COMPOSE[@]}" --profile wp-verify up -d mysql wordpress wpcli
    else
      "${COMPOSE[@]}" --profile wp-verify up -d mysql wordpress wpcli jetpack-ai
    fi
    echo "WordPress stack started."
    echo "Wait for wpcli setup, then run:"
    echo "  docker logs -f jetpack-ai-wpcli   # ready when you see: sleep infinity"
    echo "  docker exec -it jetpack-ai-sandbox bash"
    echo "  NODE_PATH=\$(npm root -g) node tools/ai-sandbox/wp-verify/check.cjs"
    ;;
  down)
    "${COMPOSE[@]}" --profile wp-verify down
    ;;
  *)
    echo "Usage: $0 [up|down]" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
# Manage the wp-verify WordPress stack for premium-analytics UI verification.
#
# Usage (from anywhere inside the jetpack repo, or from inside jetpack-ai-sandbox):
#   tools/ai-sandbox/wp-verify.sh up    # start WordPress stack + sandbox with Docker socket
#   tools/ai-sandbox/wp-verify.sh down  # stop everything
#
# Parallel-isolation: set WP_VERIFY_INSTANCE=<id> in the environment to run a
# second (or third) wp-verify stack alongside an existing one on the same host.
# Container names, the Compose project, volumes, and networks all gain a
# matching `-<id>` suffix so two stacks do not collide. Default (env unset)
# preserves the historical names (`jetpack-ai-sandbox`, `jetpack-ai-mysql`,
# etc.) so existing single-stack flows are unaffected.
#
# WP_VERIFY_INSTANCE must match `[a-z0-9][a-z0-9_-]*` (lowercase alphanumeric
# plus `-` and `_`, starting with alphanumeric) — Docker compose project names
# reject other characters and would otherwise surface as cryptic compose errors.
#
# New instances must be started from the host. Running `wp-verify.sh up` with
# WP_VERIFY_INSTANCE set from inside an existing sandbox container starts only
# the WP services (mysql/wordpress/wpcli) under the requested suffix; the
# corresponding jetpack-ai sandbox container is not started from inside, so
# exec'ing into it later would fail. The script blocks this case explicitly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional per-instance suffix for parallel runs. Empty (default) preserves
# historical names; set to a short token (e.g. an issue ID) for isolation.
INSTANCE="${WP_VERIFY_INSTANCE:-}"
if [ -n "$INSTANCE" ] && ! printf '%s' "$INSTANCE" | grep -qE '^[a-z0-9][a-z0-9_-]*$'; then
  echo "Error: WP_VERIFY_INSTANCE='$INSTANCE' is invalid." >&2
  echo "       Must match [a-z0-9][a-z0-9_-]* (lowercase alphanumeric plus '-' and '_', starting alphanumeric)." >&2
  exit 1
fi
SUFFIX="${INSTANCE:+-${INSTANCE}}"

# Container names — kept in sync with `${WP_VERIFY_INSTANCE:+-${WP_VERIFY_INSTANCE}}`
# interpolations in docker-compose.yml.
SANDBOX_NAME="jetpack-ai-sandbox${SUFFIX}"
MYSQL_NAME="jetpack-ai-mysql${SUFFIX}"
WORDPRESS_NAME="jetpack-ai-wordpress${SUFFIX}"
WPCLI_NAME="jetpack-ai-wpcli${SUFFIX}"

# Compose project name — namespaces networks + named volumes per instance.
# Default ("ai-sandbox") matches the historical name auto-derived from
# `--project-directory "$SCRIPT_DIR"` when WP_VERIFY_INSTANCE is unset.
PROJECT_NAME="ai-sandbox${SUFFIX}"

# Export so docker compose can interpolate ${WP_VERIFY_INSTANCE} inside YAML.
export WP_VERIFY_INSTANCE

# Detect JETPACK_HOST_PATH — the jetpack root on the HOST filesystem.
# Docker bind mounts are resolved by the host daemon, so we must pass the host path
# even when running this script from inside the sandbox container.
if [ -f /.dockerenv ]; then
  # Inside sandbox: inspect the *current* container (via $HOSTNAME = container's
  # short ID) rather than the suffixed name we'd build — this works regardless
  # of whether WP_VERIFY_INSTANCE matches the current container's instance, and
  # makes "extend WP services for the current instance" the supported in-sandbox
  # flow. Starting a *new* (different-instance) stack from inside is blocked
  # below; from-host invocation is the supported way to create new instances.
  JETPACK_HOST_PATH=$(docker inspect "$HOSTNAME" \
    --format '{{range .Mounts}}{{if eq .Destination "/home/dev/jetpack"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)
  if [ -z "$JETPACK_HOST_PATH" ]; then
    echo "Error: could not detect host jetpack path from current container ($HOSTNAME)." >&2
    echo "       Is /home/dev/jetpack mounted from the host?" >&2
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
  -p "$PROJECT_NAME"
)

case "${1:-up}" in
  up)
    echo "JETPACK_HOST_PATH=$JETPACK_HOST_PATH"
    if [ -f /.dockerenv ]; then
      # Inside sandbox: jetpack-ai is already running; only start the WP services.
      # If WP_VERIFY_INSTANCE was set to bring up a *different* stack from inside
      # this container, block it — we'd need to start a second jetpack-ai
      # container, which compose won't do here (no Docker socket on jetpack-ai
      # under the base file alone), and the suffixed sandbox wouldn't exist for
      # the user to exec into. Direct them to invoke from the host instead.
      CURRENT_INSTANCE=$(docker inspect "$HOSTNAME" \
        --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || true)
      if [ -n "$INSTANCE" ] && [ "$CURRENT_INSTANCE" != "$PROJECT_NAME" ]; then
        echo "Error: requested instance '$INSTANCE' (project '$PROJECT_NAME') differs from the current container's project ('$CURRENT_INSTANCE')." >&2
        echo "       New instances must be started from the host, not from inside another sandbox container." >&2
        exit 1
      fi
      "${COMPOSE[@]}" --profile wp-verify up -d mysql wordpress wpcli
    else
      "${COMPOSE[@]}" --profile wp-verify up -d mysql wordpress wpcli jetpack-ai
    fi
    echo "WordPress stack started${INSTANCE:+ (instance: $INSTANCE)}."
    echo "Wait for wpcli setup, then run:"
    echo "  docker logs -f $WPCLI_NAME   # ready when you see: sleep infinity"
    echo "  docker exec -it $SANDBOX_NAME bash"
    echo "  NODE_PATH=\$(npm root -g) node tools/ai-sandbox/wp-verify/check.cjs"
    ;;
  down)
    if [ -f /.dockerenv ]; then
      # Inside sandbox: only stop WP services; stopping jetpack-ai would kill this session.
      "${COMPOSE[@]}" --profile wp-verify stop mysql wordpress wpcli
      "${COMPOSE[@]}" --profile wp-verify rm -f mysql wordpress wpcli
    else
      "${COMPOSE[@]}" --profile wp-verify down
    fi
    ;;
  *)
    echo "Usage: $0 [up|down]" >&2
    exit 1
    ;;
esac

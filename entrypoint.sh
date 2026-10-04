#!/bin/bash
# Writes manager.yaml from the environment and runs the agent in the foreground.
# The agent_id is kept across restarts so the container shows up as the same agent.
set -e

MANAGER_YAML=/opt/observiq-otel-collector/manager.yaml

if [ -z "$BINDPLANE_SECRET_KEY" ]; then
  echo "BINDPLANE_SECRET_KEY is not set, see .env.example" >&2
  exit 1
fi

agent_id="$(grep -s '^agent_id:' "$MANAGER_YAML" || true)"
{
  [ -n "$agent_id" ] && echo "$agent_id"
  printf 'endpoint: "%s"\n' "${BINDPLANE_ENDPOINT:-wss://app.bindplane.com/v1/opamp}"
  printf 'secret_key: "%s"\n' "$BINDPLANE_SECRET_KEY"
  [ -n "$BINDPLANE_LABELS" ] && printf 'labels: "%s"\n' "$BINDPLANE_LABELS"
  [ -n "$BINDPLANE_AGENT_NAME" ] && printf 'agent_name: "%s"\n' "$BINDPLANE_AGENT_NAME"
} > "$MANAGER_YAML"
chmod 0600 "$MANAGER_YAML"

exec /opt/observiq-otel-collector/observiq-otel-collector --config config.yaml

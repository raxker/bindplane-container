# Bindplane Agent Container

Runs the Bindplane agent (BDOT collector) in Docker. Bindplane manages the agent over OpAMP:
the image contains only the agent package, and the pipeline (sources, processors,
destinations) comes from the Bindplane configuration the agent is assigned to.

## Files

| File | Purpose |
| --- | --- |
| `Dockerfile` | Ubuntu 24.04 with the Bindplane agent `.deb` installed |
| `entrypoint.sh` | Writes `manager.yaml` from the environment and runs the agent in the foreground |
| `.env.example` | Template for the connection settings; copy to `.env` (git-ignored) |

## Configuration

Copy `.env.example` to `.env` and fill it in with the values from the install command
Bindplane shows under **Agents > Install Agent**:

| Variable | Install flag | Description |
| --- | --- | --- |
| `BINDPLANE_ENDPOINT` | `-e` | OpAMP endpoint, defaults to `wss://app.bindplane.com/v1/opamp` |
| `BINDPLANE_SECRET_KEY` | `-s` | Secret key of your Bindplane account (required) |
| `BINDPLANE_LABELS` | `-k` | Labels, e.g. `configuration=<name>` to assign a configuration |
| `BINDPLANE_AGENT_NAME` | | Optional name shown in Bindplane, defaults to the container hostname |

## Ports and log files

The setup matches the configuration in
[`bindplabe-config-sample.yaml`](../enablement-bindplane-logs/bindplabe-config-sample.yaml):

| Source | Listens on / reads | Container setting |
| --- | --- | --- |
| Syslog (RFC 3164) | UDP `5140` | `-p 5140:5140/udp` |
| NetFlow v5 | UDP `2055` | `-p 2055:2055/udp` |
| File | `/var/log/syslog`, `/var/log/audit/audit.log`, `/var/log/fail2ban.log` | `-v /var/log:/var/log:ro` |
| Agent self-monitoring | `localhost:8888` (Prometheus) | internal only, no port needed |

Missing log files are fine: the File source picks them up once they exist. If you change
the sources in Bindplane, add or remove the matching `-p` and `-v` flags.

## Build and run

```bash
cp .env.example .env    # then fill in the values
docker build -t bindplane-agent .

docker run -d --name bindplane-agent --hostname bindplane-agent \
  --env-file .env \
  -v /var/log:/var/log:ro \
  -v bindplane-storage:/opt/observiq-otel-collector/storage \
  -p 5140:5140/udp -p 2055:2055/udp \
  --restart unless-stopped \
  bindplane-agent
```

The `bindplane-storage` volume keeps the File source's read positions, so the agent
continues where it stopped instead of re-reading or skipping logs after the container is
recreated.

To pin a different agent version: `docker build --build-arg BINDPLANE_VERSION=<version> -t bindplane-agent .`

## Checking it works

- The agent appears under **Agents** in Bindplane within a few seconds.
- The agent writes its own logs to a file, not to `docker logs`:

  ```bash
  docker exec bindplane-agent tail -f /opt/observiq-otel-collector/log/collector.log
  ```

- Send a test syslog message:

  ```bash
  logger -n 127.0.0.1 -P 5140 -d --rfc3164 "hello from bindplane-agent test"
  ```

## Notes

- If `BINDPLANE_SECRET_KEY` is not set, the container exits with an error.
- The agent ID stays the same across restarts of the same container. A recreated container
  (`docker rm` + `docker run`) registers as a new agent.
- The agent runs as root inside the container so it can read the mounted host logs.

# Standalone Bindplane agent (BDOT collector) managed by Bindplane over OpAMP.
#
#   docker build -t bindplane-agent .
#   docker run -d --name bindplane-agent --hostname bindplane-agent --env-file .env bindplane-agent
#
# With the host's logs and the syslog/NetFlow listeners (see README.md)
#   docker run -d --name bindplane-agent --hostname bindplane-agent --env-file .env \
#     -v /var/log:/var/log:ro -v bindplane-storage:/opt/observiq-otel-collector/storage \
#     -p 5140:5140/udp -p 2055:2055/udp \
#     bindplane-agent
FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Only the package is baked in; endpoint and secret key are passed at runtime
# (see .env.example) so they stay out of the image.
ARG BINDPLANE_VERSION=1.109.0
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL -o /tmp/bdot.deb \
       "https://bdot.bindplane.com/v${BINDPLANE_VERSION}/observiq-otel-collector_v${BINDPLANE_VERSION}_linux_${arch}.deb" \
    && dpkg -i /tmp/bdot.deb \
    && rm /tmp/bdot.deb

ENV OIQ_OTEL_COLLECTOR_HOME=/opt/observiq-otel-collector \
    OIQ_OTEL_COLLECTOR_STORAGE=/opt/observiq-otel-collector/storage \
    BINDPLANE_COLLECTOR_HOME=/opt/observiq-otel-collector \
    BINDPLANE_COLLECTOR_STORAGE=/opt/observiq-otel-collector/storage

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Listeners of the Bindplane configuration: syslog (RFC 3164) and NetFlow.
# The self-monitoring endpoint on 8888 binds to localhost and stays internal.
EXPOSE 5140/udp 2055/udp

WORKDIR /opt/observiq-otel-collector
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

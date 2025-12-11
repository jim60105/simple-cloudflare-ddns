# syntax=docker/dockerfile:1
ARG UID=1001
ARG VERSION=EDGE
ARG RELEASE=0

########################################
# Base stage
# This is an alpine image with curl
########################################
FROM docker.io/curlimages/curl:8.17.0 AS base

########################################
# Final stage
########################################
FROM base AS final

# Create user
ARG UID
RUN adduser -g "" -D $UID -u $UID -G root

# Create directories with correct permissions
RUN install -d -m 775 -o $UID -g 0 /app && \
    install -d -m 775 -o $UID -g 0 /data && \
    install -d -m 775 -o $UID -g 0 /licenses

# Copy licenses (OpenShift Policy)
COPY --link --chown=$UID:0 --chmod=775 LICENSE /licenses/

COPY --link --chown=$UID:0 --chmod=775 updateDNS.sh /app/

WORKDIR /app

# Persistent data directory for IP cache files
VOLUME [ "/data" ]

USER $UID

STOPSIGNAL SIGINT

ENTRYPOINT [ "sh", "/app/updateDNS.sh" ]

ARG VERSION
ARG RELEASE
LABEL name="jim60105/simple-cloudflare-ddns" \
    # Authors for simple-cloudflare-ddns script
    vendor="jim60105" \
    # Maintainer for this docker image
    maintainer="jim60105" \
    # Dockerfile source repository
    url="https://github.com/jim60105/simple-cloudflare-ddns" \
    version=${VERSION} \
    # This should be a number, incremented with each change
    release=${RELEASE} \
    io.k8s.display-name="simple-cloudflare-ddns" \
    summary="A simple Cloudflare Dynamic DNS updater" \
    description="For more information about this tool, please visit the following website: https://github.com/jim60105/simple-cloudflare-ddns"

# syntax=docker/dockerfile:1
ARG UID=curl_user
ARG VERSION=EDGE
ARG RELEASE=0

########################################
# Base stage
# This is an alpine image with curl
# https://github.com/curl/curl-container
########################################
FROM docker.io/curlimages/curl:8.17.0 AS base

########################################
# Final stage
########################################
FROM base AS final

# Create directories with correct permissions
RUN install -d -m 775 /home/curl_user/data && \
    install -d -m 775 /home/curl_user/licenses

# Copy licenses (OpenShift Policy)
COPY --link --chown=$UID:0 --chmod=775 LICENSE /home/curl_user/licenses/

# Copy main script
COPY --link --chown=$UID:0 --chmod=775 updateDNS.sh /home/curl_user/

# Persistent data directory for IP cache files
VOLUME [ "/home/curl_user/data" ]

STOPSIGNAL SIGINT

ENTRYPOINT [ "sh", "/home/curl_user/updateDNS.sh" ]

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
    description="A simple Cloudflare Dynamic DNS updater that runs in a container. It updates your Cloudflare DNS A/AAAA records with your current public IP address. For more information about this tool, please visit the following website: https://github.com/jim60105/simple-cloudflare-ddns"

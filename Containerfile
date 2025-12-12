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

# Copy licenses
COPY --link --chown=$UID:0 --chmod=775 LICENSE /home/curl_user/

# Copy main script
COPY --link --chown=$UID:0 --chmod=775 updateDNS.sh /home/curl_user/

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

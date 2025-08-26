# Dockerfile for building Immich server with smart search patches
FROM ghcr.io/immich-app/immich-server:v1.122.3 as base

# Copy patches
COPY patches/add-smartsearch-score-and-album.diff /tmp/

# Apply patches to source
WORKDIR /usr/src/app
RUN apt-get update && apt-get install -y patch && \
    patch -p1 < /tmp/add-smartsearch-score-and-album.diff && \
    npm run build && \
    apt-get remove -y patch && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Final stage uses patched build
FROM base
LABEL org.opencontainers.image.description="Immich Server with Smart Search Patches"
LABEL org.opencontainers.image.source="https://github.com/menkveldj/immich-smart-search-patches"
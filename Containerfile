# Containerfile: Isolated Debian 13 (Trixie) kernel build environment
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bc \
    bison \
    flex \
    libelf-dev \
    libdw-dev \
    libssl-dev \
    dwarves \
    kmod \
    rsync \
    cpio \
    fakeroot \
    zstd \
    git \
    curl \
    ca-certificates \
    debhelper \
    libncurses-dev \
    sbsigntool \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

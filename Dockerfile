ARG S6_OVERLAY_VERSION=3.2.3.1

FROM docker.io/alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS builder
RUN apk add --no-cache \
    alpine-sdk \
    cmake \
    alsa-lib-dev \
    avahi-dev \
    bash \
    boost-dev \
    expat-dev \
    flac-dev \
    git \
    libvorbis-dev \
    opus-dev \
    pulseaudio-dev \
    soxr-dev

### SNAPCLIENT ###
RUN git clone https://github.com/badaix/snapcast.git /snapcast \
    && cd snapcast \
    && git checkout 439dc88637bb7ac227c24d8ad383e7cdf46a76d7

WORKDIR /snapcast
RUN cmake -S . -B build \
    -DBUILD_SERVER=OFF \
    -DBUILD_WITH_SSL=OFF \
    -DBUILD_WITH_ALSA=ON \
    -DBUILD_WITH_FLAC=ON \
    -DBUILD_WITH_VORBIS=ON \
    -DBUILD_WITH_OPUS=ON \
    -DBUILD_WITH_AVAHI=ON \
    -DBUILD_WITH_EXPAT=ON \
    -DBUILD_WITH_PULSE=OFF \
    -DBUILD_WITH_JACK=OFF \
    -DBUILD_WITH_PIPEWIRE=OFF \
    && cmake --build build -j $(nproc) --verbose \
    && strip -s ./bin/snapclient
WORKDIR /

# Gather all shared libaries necessary to run the executable
RUN mkdir /snapclient-libs \
    && ldd /snapcast/bin/snapclient| cut -d" " -f3 | xargs cp --dereference --target-directory=/snapclient-libs/

### SNAPCLIENT END ###

###### BASE START ######
FROM docker.io/alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS base
ARG S6_OVERLAY_VERSION
ARG TARGETARCH

RUN apk add --no-cache \
    avahi \
    alsa-lib \
    dbus \
    fdupes

# Removes all libaries that will be installed in the final image
COPY --from=builder /snapclient-libs/ /tmp-libs/
RUN fdupes -d -N /tmp-libs/ /usr/lib/

# Install s6 - map Docker's TARGETARCH to s6-overlay architecture names
RUN case "${TARGETARCH}" in \
      amd64) S6_ARCH="x86_64" ;; \
      arm64) S6_ARCH="aarch64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && wget -O /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
    && wget -O /tmp/s6-overlay-arch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-arch.tar.xz \
    && rm -rf /tmp/*

###### BASE END ######

###### MAIN START ######
FROM docker.io/alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

ENV S6_CMD_WAIT_FOR_SERVICES=1
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

RUN apk add --no-cache \
            avahi \
            alsa-lib \
            dbus \
    && rm -rf /lib/apk/db/*

# Copy extracted s6-overlay and libs from base
COPY --from=base /command /command/
COPY --from=base /package/ /package/
COPY --from=base /etc/s6-overlay/ /etc/s6-overlay/
COPY --from=base init /init
COPY --from=base /tmp-libs/ /usr/lib/

# Copy necessary files from the builder
COPY --from=builder /snapcast/bin/snapclient /usr/local/bin/

COPY ./s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d
RUN chmod +x /etc/s6-overlay/s6-rc.d/01-startup/script.sh

RUN mkdir -p /var/run/dbus/

ENTRYPOINT ["/init"]
###### MAIN END ######

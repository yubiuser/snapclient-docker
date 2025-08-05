ARG S6_OVERLAY_VERSION=3.2.1.0

FROM docker.io/alpine:3.22 AS builder
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
    && git checkout b7c23f077e8e77ed40f6467c81d0da364722aa0a

WORKDIR /snapcast
RUN cmake -S . -B build -DBUILD_SERVER=OFF \
    && cmake --build build -j $(( $(nproc) -1 )) --verbose \
    && strip -s ./bin/snapclient
WORKDIR /

# Gather all shared libaries necessary to run the executable
RUN mkdir /snapclient-libs \
    && ldd /snapcast/bin/snapclient| cut -d" " -f3 | xargs cp --dereference --target-directory=/snapclient-libs/

### SNAPCLIENT END ###

###### BASE START ######
FROM docker.io/alpine:3.22 AS base
ARG S6_OVERLAY_VERSION
ARG S6_ARCH=x86_64

RUN apk add --no-cache \
    avahi \
    alsa-lib \
    dbus \
    fdupes

# Removes all libaries that will be installed in the final image
COPY --from=builder /snapclient-libs/ /tmp-libs/
RUN fdupes -d -N /tmp-libs/ /usr/lib/

# Install s6
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz /tmp/
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz \
    && rm -rf /tmp/*

###### BASE END ######

###### MAIN START ######
FROM docker.io/alpine:3.22

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

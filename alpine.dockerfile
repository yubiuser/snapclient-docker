FROM docker.io/alpine:3.18 as builder
RUN apk add --no-cache \
    alpine-sdk \
    cmake \
    alsa-lib-dev \
    avahi-dev \
    bash \
    boost-dev \
    flac-dev \
    git \
    libvorbis-dev \
    opus-dev \
    pulseaudio-dev \
    soxr-dev

### SNAPCLIENT ###
RUN git clone https://github.com/badaix/snapcast.git /snapcast \
    && cd snapcast \
    && git checkout 481f08199ca31c60c9a3475f1064e6b06a503d12

WORKDIR /snapcast
RUN cmake -S . -B build -DBUILD_SERVER=OFF \
    && cmake --build build -j $(( $(nproc) -1 )) --verbose \
    && strip -s ./bin/snapclient
WORKDIR /

### SNAPCLIENT END ###

###### BASE START ######
FROM docker.io/alpine:3.18 as base
ARG S6_OVERLAY_VERSION=3.1.5.0
RUN apk add --no-cache \
    fdupes
# Removes all libaries that are installed already in the base image
#COPY --from=librespot /librespot-libs/ /tmp-libs/
#RUN fdupes -d -N /tmp-libs/ /usr/lib/

# Install s6
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
    && rm -rf /tmp/*

###### BASE END ######

###### MAIN START ######
FROM docker.io/alpine:3.18
RUN apk add --no-cache \
            avahi \
            dbus \
    && rm -rf /lib/apk/db/*

# Copy extracted s6-overlay and libs from base
COPY --from=base /command /command/
COPY --from=base /package/ /package/
COPY --from=base /etc/s6-overlay/ /etc/s6-overlay/
COPY --from=base init /init

# Copy necessary files from the builder
COPY --from=builder /snapcast/bin/snapclient /usr/local/bin/

COPY ./s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d
RUN chmod +x /etc/s6-overlay/s6-rc.d/01-startup/script.sh

RUN mkdir -p /var/run/dbus/

ENTRYPOINT ["/init"]
###### MAIN END ######

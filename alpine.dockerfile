FROM docker.io/alpine:3.17 as builder
RUN apk add --no-cache \
    alpine-sdk \
    alsa-lib-dev \
    avahi-dev \
    bash \
    boost1.80-dev \
    flac-dev \
    git \
    libvorbis-dev \
    opus-dev \
    pulseaudio-dev \
    soxr-dev

### SNAPCLIENT ###
RUN git clone https://github.com/badaix/snapcast.git /snapcast \
    && cd snapcast \
    && git checkout 0b343d4b1489584a3c15c18fa49702ae9a364116

WORKDIR /snapcast
RUN  make -j $(( $(nproc) -1 )) client
WORKDIR /
### SNAPCLIENT END ###

###### MAIN START ######
FROM docker.io/crazymax/alpine-s6:3.17-3.1.1.2
RUN apk add --no-cache  alsa-lib \
                        avahi-libs \
                        avahi \
                        avahi-tools \
                        dbus \
                        flac-libs \
                        libogg \
                        libpulse \
                        libstdc++ \
                        libgcc \
                        libvorbis \
                        opus \
                        soxr

# Copy necessary files from the builder
COPY --from=builder /snapcast/client/snapclient /usr/local/bin/

COPY ./s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d
RUN chmod +x /etc/s6-overlay/s6-rc.d/01-startup/script.sh

###### MAIN END ######

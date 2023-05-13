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
    && git checkout 481f08199ca31c60c9a3475f1064e6b06a503d12

WORKDIR /snapcast
RUN cmake -S . -B build -DBUILD_SERVER=OFF \
    && cmake --build build -j $(( $(nproc) -1 )) --verbose \
    && strip -s ./bin/snapclient
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
COPY --from=builder /snapcast/bin/snapclient /usr/local/bin/

COPY ./s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d
RUN chmod +x /etc/s6-overlay/s6-rc.d/01-startup/script.sh

###### MAIN END ######

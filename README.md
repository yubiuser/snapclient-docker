# snapclient-docker

Alpine based Docker image for running the [snapclient part of snapcast](https://github.com/badaix/snapcast). This is the counterpart to [https://github.com/yubiuser/librespot-shairport-snapserver](https://github.com/yubiuser/librespot-shairport-snapserver)

 **Note:** Current last commit of the development branche is used to compile the lastest versions.

## Getting started

Images for `amd64` can be found at [ghcr.io/yubiuser/snapclient-docker](ghcr.io/yubiuser/snapclient-docker).

Use with

```plain
docker pull ghcr.io/yubiuser/snapclient-docker
docker run -d --rm --net host --device /dev/snd --name snapclient snapclient-docker
```
2023-05-13 12-07-50.425 [Info]
or with `docker-compose.yml`

```yml
version: "3"
services:
  snapclient:
    image: ghcr.io/yubiuser/snapclient-docker
    container_name: snapclient
    restart: unless-stopped
    network_mode: host
    environment:
        - ARG=--player file:filename=null
    devices:
        - "/dev/snd:/dev/snd"
```

### Build locally

To build the image simply run

`docker build -t snapclient-docker:local -f ./alpine.dockerfile .`

Start the container with

`docker run -d --rm --net host --device /dev/snd --name snapclient snapclient-docker:local`

### Passing Arguments

To pass command line arguments to `snapclient` (for a list of possible arguemtens, [see here](https://github.com/badaix/snapcast#client))
set `-e ARG="xy"` within the docker call or specify them within the `compose.yml`
For example

```shell
docker run -d --rm --net host --device /dev/snd \
-e ARG="--player alsa" --name snapclient snapclient-docker:local`
```

## Notes

- Based on current Alpine version 3:17
- Final image size is ~59 MB
- The `make` calles use the option `-j $(( $(nproc) -1 ))` to leave one CPU for normal operation
- `s6-overlay` is used as `init` system
  - The `ENTRYPOINT ["/init"]` is set within the [docker-alpine-s6 base image](https://github.com/crazy-max/docker-alpine-s6) already
  - `s6-rc` with configured dependencies is used to start all services. `snapclient` should start as last
  - `s6-rc` considers *longrun* services as "started" when the `run` file is executed. However, some services need a bit time to fully startup. To not breake dependent services, they check for existence of `*.pid` files of previous services

# snapclient-docker

Alpine based Docker image for running the [snapclient part of snapcast](https://github.com/badaix/snapcast). This is the counterpart to [https://github.com/yubiuser/librespot-shairport-snapserver](https://github.com/yubiuser/librespot-shairport-snapserver)

 **Note:** Current last commit of the development branche is used to compile the lastest versions.

## Getting started

Images for `amd64` can be found at [ghcr.io/yubiuser/yubiuser/snapclient-docker](https://github.com/yubiuser/snapclient-docker/pkgs/container/yubiuser%2Fsnapclient-docker).

Use with

```plain
docker pull ghcr.io/yubiuser/yubiuser/snapclient-docker
docker run -d --rm --net host --device /dev/snd --name snapclient snapclient-docker
```

or with `docker-compose.yml`

```yml
version: "3"
services:
  snapclient:
    image: ghcr.io/yubiuser/yubiuser/snapclient-docker
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

- Based on current Alpine version 3:20
- Final image size is ~27 MB
- The `make` calles use the option `-j $(( $(nproc) -1 ))` to leave one CPU for normal operation
- `s6-overlay` is used as `init` system
  - `s6-rc` with configured dependencies is used to start all services. `snapclient` should start as last

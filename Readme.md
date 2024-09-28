# Manually Build qBittorrent-ut-nox Docker Image

This Dockerfile allows you to build a Docker Image containing qBittorrent-ut-nox

## What is qBittorrent-ut-nox?

qBittorrent-ut-nox is custom qBittorrent-nox built with a few targets in mind

replacing qBittorrent's client id and user-agent to make it no longer qBittorrent

I'm using "UT" and "uTorrent" as replacement to mimic µTorrent signature

even though, "uTorrent" is incorrect user-agent for real µTorrent

It works for some trackers those blocked qBittorrent. Good enough for my personal usage

This also remove QBT_EULA=accept requirement from original one.

## Prerequisites

In order to build/run this image you'll need Docker installed: https://docs.docker.com/get-docker/

If you don't need the GUI, you can just install Docker Engine: https://docs.docker.com/engine/install/

It is also recommended to install Docker Compose as it can significantly ease the process: https://docs.docker.com/compose/install/

## Building Docker Image

* If you are using Docker (not Docker Compose) then run the following commands in this folder:
  ```shell
  export \
    QBT_VERSION=latest
  docker build \
    --build-arg QBT_VERSION \
    -t qbittorrent-ut-nox:"$QBT_VERSION" \
    .
  ```

* If you are using Docker Compose then you should edit `.env` file first.
  You can find an explanation of the variables in the following [Parameters](#parameters) section. \
  Then run the following commands in this folder:
  ```shell
  docker compose build \
    --build-arg QBT_VERSION
  ```

### Parameters

#### Environment variables

* `QBT_EULA` (Optional) \
  This environment variable defines whether you accept the end-user license agreement (EULA) of qBittorrent. \
  **Put `accept` only if you understand and accepted the EULA.** You can find
  the EULA [here](https://github.com/qbittorrent/qBittorrent/blob/56667e717b82c79433ecb8a5ff6cc2d7b315d773/src/app/main.cpp#L320-L323). \
  _**This is no longer required for fresh install, but may be required if you didn't agree before.**_
* `QBT_VERSION` \
  This environment variable specifies the version of qBittorrent-nox to be built. \
  For example, `4.4.0` is a valid entry. You can find all tagged versions [here](https://github.com/qbittorrent/qBittorrent/tags). \
  You can put `latest` to build the latest stable version, or you can put `devel` to build the latest development version.
* `QBT_WEBUI_PORT` \
  This environment variable sets the port number which qBittorrent WebUI will be binded to.
  Defaults to port `8080` if value is not set.

#### Volumes

There are some paths involved:
* `<your_path>/config` \
  Full path to a folder on your host machine which will store qBittorrent configurations.
  Using relative path won't work.
* `<your_path>/downloads` \
  Full path to a folder on your host machine which will store the files downloaded by qBittorrent.
  Using relative path won't work.

## Running container

* Using Docker (not Docker Compose), simply run:
  ```shell
  export \
    QBT_VERSION=latest \
    QBT_WEBUI_PORT=8080 \
    QBT_CONFIG_PATH="<your_path>/config" \
    QBT_DOWNLOADS_PATH="<your_path>/downloads"
  docker run \
    -t \
    --name qbittorrent-ut-nox \
    --read-only \
    --rm \
    --stop-timeout 1800 \
    --tmpfs /tmp \
    -e QBT_WEBUI_PORT \
    -e TZ=UTC \
    -p "$QBT_WEBUI_PORT":"$QBT_WEBUI_PORT"/tcp \
    -p 6881:6881/tcp \
    -p 6881:6881/udp \
    -v "$QBT_CONFIG_PATH":/config \
    -v "$QBT_DOWNLOADS_PATH":/downloads \
    qbittorrent-ut-nox:"$QBT_VERSION"
  ```

* Using Docker Compose:
  ```shell
  docker compose up
  ```

* A few notes:
  * By default the timezone in the container uses the default of Alpine Linux (which is most likely `UTC`).
    You can set the environment variable `TZ` to your preferred value.
  * You can change the User ID (UID) and Group ID (GID) of the `qbittorrent-nox` process by setting
    environment variables `PUID` and `PGID` respectively. By default they are both set to `1000`. \
    Note that you will need to remove `--read-only` flag (when using Docker) or set
    `read_only: false` (when using Docker Compose) as they are incompatible with it.
  * You can set additional group ID (AGID) of the `qbittorrent-nox` process by setting the
    environment variable `PAGID`. For example: `10000,10001`, this will set the process to be in
    two (secondary) groups `10000` and `10001`. By default there is no additional group. \
    Note that you will need to remove `--read-only` flag (when using Docker) or set
    `read_only: false` (when using Docker Compose) as they are incompatible with it.
  * It is possible to set the umask of the `qbittorrent-nox` process by setting the
    environment variable `UMASK`. By default it uses the default from Alpine Linux.
  * You can list the compile-time Software Bill of Materials (sbom) with the following command:
    ```shell
    docker run --entrypoint /bin/cat --rm qbittorrent-ut-nox:latest /sbom.txt
    ```

* Then you can login to qBittorrent-nox at: `http://<your_docker_host_address>:8080`
  * For older qBittorrent versions (< 4.6.1), the default username/password is: `admin/adminadmin`.
  * For newer qBittorrent versions (≥ 4.6.1), qBittorrent will generate a temporary password and print it to the console (via stdout).
    You need to use it to login. See the [announcement](https://www.qbittorrent.org/news#mon-nov-20th-2023---qbittorrent-v4.6.1-release). \
    If you don't have a console attached, you can run `docker logs qbittorrent-ut-nox` to show the logs.

  After logging in, don't forget to change the password to something else! \
  To change it in WebUI: 'Tools' menu -> 'Options...' -> 'Web UI' tab -> 'Authentication'

## Stopping container

* Using Docker (not Docker Compose):
  ```shell
  docker stop qbittorrent-ut-nox
  ```

* Using Docker Compose:
  ```shell
  docker compose down
  ```

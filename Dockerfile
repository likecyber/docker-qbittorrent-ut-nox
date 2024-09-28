# create an up-to-date base image for everything
FROM alpine:latest AS base

RUN \
  apk --no-cache --update-cache upgrade

# run-time dependencies
RUN \
  apk --no-cache add \
    coreutils \
    curl \
    doas \
    grep \
    jq \
    python3 \
    qt6-qtbase \
    qt6-qtbase-sqlite \
    sed \
    tini \
    tzdata \
    bash

# image for building
FROM base AS builder

ARG QBT_VERSION="latest"
ARG LIBBT_VERSION="RC_1_2"
ARG LIBBT_CMAKE_FLAGS=""

# alpine linux packages:
# https://git.alpinelinux.org/aports/tree/community/libtorrent-rasterbar/APKBUILD
# https://git.alpinelinux.org/aports/tree/community/qbittorrent/APKBUILD
RUN \
  apk add \
    boost-dev \
    cmake \
    git \
    g++ \
    ninja \
    openssl-dev \
    qt6-qtbase-dev \
    qt6-qttools-dev

# compiler, linker options:
# https://gcc.gnu.org/onlinedocs/gcc/Option-Summary.html
# https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html
# https://sourceware.org/binutils/docs/ld/Options.html
ENV CFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
    CXXFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
    LDFLAGS="-gz -Wl,-O1,--as-needed,--sort-common,-z,now,-z,pack-relative-relocs,-z,relro"

# build libtorrent
RUN \
  git clone \
    --branch "${LIBBT_VERSION}" \
    --depth 1 \
    --recurse-submodules \
    https://github.com/arvidn/libtorrent.git && \
  cd libtorrent && \
  cmake \
    -B build \
    -G Ninja \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -Ddeprecated-functions=OFF \
    $LIBBT_CMAKE_FLAGS && \
  cmake --build build -j $(nproc) && \
  cmake --install build

# build qbittorrent
RUN \
  if [ "${QBT_VERSION}" = "devel" ]; then \
    git clone \
      --depth 1 \
      --recurse-submodules \
      https://github.com/qbittorrent/qBittorrent.git && \
    cd qBittorrent ; \
  else \
    if [ "${QBT_VERSION}" = "latest" ]; then \
      QBT_VERSION=$(curl -s https://api.github.com/repos/qbittorrent/qBittorrent/tags | jq -r '.[].name' | grep -E '^release-[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr | head -n 1 | sed 's/^release-//') && \
      echo "Using latest stable version: ${QBT_VERSION}"; \
    fi && \
    wget "https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-${QBT_VERSION}.tar.gz" && \
    tar -xf "release-${QBT_VERSION}.tar.gz" && \
    cd "qBittorrent-release-${QBT_VERSION}" ; \
  fi && \
  grep -Elr "\"qB\"|\"qBittorrent/\"" . | while read -r file; do echo "Patching: $file"; sed -i -e "s/\"qB\"/\"UT\"/g" -e "s/\"qBittorrent\/\"/\"uTorrent \"/g" "$file"; done && \
  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DGUI=OFF \
    -DQT6=ON && \
  cmake --build build -j $(nproc) && \
  cmake --install build

RUN \
  ldd /usr/bin/qbittorrent-nox | sort -f

# record compile-time Software Bill of Materials (sbom)
RUN \
  printf "Software Bill of Materials for building qbittorrent-nox\n\n" >> /sbom.txt && \
  cd libtorrent && \
  echo "libtorrent-rasterbar git $(git rev-parse HEAD)" >> /sbom.txt && \
  cd .. && \
  if [ "${QBT_VERSION}" = "devel" ]; then \
    cd qBittorrent && \
    echo "qBittorrent git $(git rev-parse HEAD)" >> /sbom.txt && \
    cd .. ; \
  else \
    echo "qBittorrent ${QBT_VERSION}" >> /sbom.txt ; \
  fi && \
  echo >> /sbom.txt && \
  apk list -I | sort >> /sbom.txt && \
  cat /sbom.txt

# image for running
FROM base

RUN \
  adduser \
    -D \
    -H \
    -s /sbin/nologin \
    -u 1000 \
    qbtUser && \
  echo "permit nopass :root" >> "/etc/doas.d/doas.conf"

COPY --from=builder /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

COPY --from=builder /sbom.txt /sbom.txt

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]

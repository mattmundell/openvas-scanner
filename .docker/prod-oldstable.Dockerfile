ARG VERSION=edge
# this allows to work on forked repository
ARG REPOSITORY=greenbone/openvas-scanner
ARG GVM_LIBS_VERSION=oldstable

FROM greenbone/openvas-smb:oldstable-edge AS openvas-smb

FROM registry.community.greenbone.net/community/gvm-libs:${GVM_LIBS_VERSION} AS build
COPY . /source
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
  bison \
  build-essential \
  clang \
  clang-format \
  clang-tools \
  cmake \
  curl \
  lcov \
  libcjson1 \
  libgnutls28-dev \
  libgpgme-dev \
  libjson-glib-dev \
  libksba-dev \
  libpaho-mqtt-dev \
  libpcap-dev \
  libssh-gcrypt-dev \
  libbsd-dev \
  libgnutls30 \
  libgssapi3-heimdal \
  libkrb5-26-heimdal \
  libasn1-8-heimdal \
  libroken18-heimdal \
  libhdb9-heimdal \
  libpopt0 \
  libcurl4-gnutls-dev \
  libcurl4 \
  # libcgreen1-dev \
  libhiredis-dev \
  libkrb5-dev \
  && rm -rf /var/lib/apt/lists/*

RUN curl -L -o cgreen.tar.gz https://github.com/cgreen-devs/cgreen/archive/refs/tags/1.6.3.tar.gz -k
RUN tar -xzf cgreen.tar.gz && cd cgreen-1.6.3
RUN make install
RUN ldconfig
COPY --from=openvas-smb /usr/local/lib/ /usr/local/lib/
RUN cmake -DCMAKE_BUILD_TYPE=Release -DINSTALL_OLD_SYNC_SCRIPT=OFF -B/build /source
RUN DESTDIR=/install cmake --build /build -- install
# TODO: add rust?

FROM registry.community.greenbone.net/community/gvm-libs:${GVM_LIBS_VERSION}
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
  bison \
  libglib2.0-0 \
  libjson-glib-1.0-0 \
  libksba8 \
  nmap \
  libcap2-bin \
  snmp \
  netdiag \
  pnscan \
  libbsd0 \
  rsync \
  # net-tools is required by some nasl plugins.
  # nasl_pread: Failed to execute child process “netstat” (No such file or directory)
  net-tools \
  # for openvas-smb support
  python3-impacket \
  libgnutls30 \
  libgssapi3-heimdal \
  libkrb5-26-heimdal \
  libasn1-8-heimdal \
  libroken18-heimdal \
  libhdb9-heimdal \
  libpopt0 \
  libcurl4 \
  libcurl3-gnutls \
  libhiredis0.14 \
  zlib1g\
  && rm -rf /var/lib/apt/lists/*
COPY .docker/openvas.conf /etc/openvas/
COPY --from=build /install/ /
COPY --from=openvas-smb /usr/local/lib/ /usr/local/lib/
COPY --from=openvas-smb /usr/local/bin/ /usr/local/bin/
RUN ldconfig
# allow openvas to access raw sockets and all kind of network related tasks
RUN setcap cap_net_raw,cap_net_admin+eip /usr/local/sbin/openvas
# allow nmap to send e.g. UDP or TCP SYN probes without root permissions
ENV NMAP_PRIVILEGED=1
RUN setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip /usr/bin/nmap

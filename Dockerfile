# The MIT License
#
# Copyright (c) 2021, Serhiy Makarenko

FROM debian:10-slim AS builder
MAINTAINER Andreas Roth "aroth@arsoft-online.com"
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.license=GPL-3.0 \
    org.label-schema.name=isc-kea-dhcp4 \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url=https://github.com/aroth-arsoft/docker-isc-kea-dhcp4

ARG KEA_VERSION=2.0.0
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
    bison flex automake libtool pkg-config build-essential ccache \
    libboost-dev libboost-system-dev liblog4cplus-dev libssl-dev \
    default-libmysqlclient-dev postgresql-server-dev-all libpq-dev \
    python3-sphinx python3-sphinx-rtd-theme \
    apt-utils gnupg curl debian-keyring apt-transport-https ca-certificates && \
    c_rehash && \
    curl -RL -O "https://ftp.isc.org/isc/kea/${KEA_VERSION}/kea-${KEA_VERSION}.tar.gz" && \
    tar xvzf kea-${KEA_VERSION}.tar.gz

ARG PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
ARG PATH="/usr/lib64/ccache:$PATH"

RUN cd kea-${KEA_VERSION} && \
    autoreconf --install && \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --with-openssl \
        --with-mysql \
        --with-pgsql \
        --with-boost-libs=-lboost_system \
        --enable-generate-docs \
        --enable-shell \
        --disable-static \
        --disable-rpath \
        --enable-generate-parser \
        --disable-dependency-tracking \
        --without-werror && \
    make -j3 && \
    make install-strip && \
    echo "/usr/local/lib/hooks" > /etc/ld.so.conf.d/kea.conf && \
    ldconfig

RUN cd /usr/lib && \
    mkdir isc-kea-common-libs && \
    for lib in asiodns asiolink cc cfgclient cryptolink d2srv database dhcp++ dhcp_ddns dhcpsrv dns++ eval exceptions hooks http log mysql pgsql process stats threads util-io util; do for libso in `ls libkea-${lib}.so*`; do mv ${libso} isc-kea-common-libs/; done; done && \
    cd /usr/lib/kea/hooks && \
    mkdir isc-kea-common-hooks && \
    for hook in libdhcp_ha libdhcp_lease_cmds libdhcp_mysql_cb libdhcp_stat_cmds; do mv ${hook}.so isc-kea-common-hooks/; done


#
# FROM debian:10-slim as isc-kea-dhcp-ddns-server
# LABEL maintainer="serhiy.makarenko@me.com"
#
# ARG DEBIAN_FRONTEND=noninteractive
#
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends --no-install-suggests \
#     liblog4cplus-1.1-9 libssl1.1 libboost-system1.67.0 && \
#     rm -rf /var/lib/apt/lists/*
#
# RUN mkdir /var/run/kea && mkdir /var/lib/kea && mkdir /etc/kea
#
# COPY --from=builder /usr/lib/isc-kea-common-libs /usr/lib/
# COPY --from=builder /usr/lib/kea/hooks/isc-kea-common-hooks /usr/lib/kea/hooks
# COPY --from=builder /usr/sbin/kea-lfc /usr/sbin
# COPY --from=builder /usr/sbin/kea-dhcp-ddns /usr/sbin
# COPY --from=builder /etc/kea/kea-dhcp-ddns.conf /etc/kea
# COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
# COPY --from=builder /usr/share/man/man8/kea-dhcp-ddns.8 /usr/share/man/man8
#
# ENTRYPOINT ["/usr/sbin/kea-dhcp-ddns"]
# CMD ["-c", "/etc/kea/kea-dhcp-ddns.conf"]
#
# FROM debian:10-slim as isc-kea-ctrl-agent
# LABEL maintainer="serhiy.makarenko@me.com"
#
# ARG DEBIAN_FRONTEND=noninteractive
#
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends --no-install-suggests \
#     liblog4cplus-1.1-9 libssl1.1 libboost-system1.67.0 && \
#     rm -rf /var/lib/apt/lists/*
#
# RUN mkdir /var/run/kea && mkdir /var/lib/kea && mkdir /etc/kea
#
# COPY --from=builder /usr/lib/isc-kea-common-libs /usr/lib/
# COPY --from=builder /usr/lib/kea/hooks/isc-kea-common-hooks /usr/lib/kea/hooks
# COPY --from=builder /usr/sbin/kea-lfc /usr/sbin
# COPY --from=builder /usr/sbin/kea-shell /usr/sbin
# COPY --from=builder /usr/sbin/kea-ctrl-agent /usr/sbin
# COPY --from=builder /etc/kea/kea-ctrl-agent.conf /etc/kea
# COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
# COPY --from=builder /usr/share/man/man8/kea-shell.8 /usr/share/man/man8
# COPY --from=builder /usr/share/man/man8/kea-ctrl-agent.8 /usr/share/man/man8
#
# ENTRYPOINT ["/usr/sbin/kea-ctrl-agent"]
# CMD ["-c", "/etc/kea/kea-ctrl-agent.conf"]

FROM debian:10-slim as isc-kea-dhcp4-server
LABEL maintainer="serhiy.makarenko@me.com"

ARG DEBIAN_FRONTEND=noninteractive
ADD *.gpg /etc/apt/trusted.gpg.d/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y ca-certificates apt-transport-https \
        supervisor prometheus-node-exporter net-tools iputils-ping mariadb-client \
        liblog4cplus-1.1-9 libssl1.1 libboost-system1.67.0 libmariadb3 libpq5 && \
    echo "deb [arch=amd64] https://dl.cloudsmith.io/public/isc/stork/deb/debian buster main" >> /etc/apt/sources.list.d/isc-stork.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests isc-stork-agent && \
    rm -rf /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /var/run/kea && mkdir /var/lib/kea && mkdir /etc/kea

COPY --from=builder /usr/lib/isc-kea-common-libs /usr/lib/
COPY --from=builder /usr/lib/kea/hooks/isc-kea-common-hooks /usr/lib/kea/hooks
COPY --from=builder /usr/sbin/kea-admin /usr/sbin
COPY --from=builder /usr/sbin/kea-lfc /usr/sbin
COPY --from=builder /usr/sbin/kea-dhcp4 /usr/sbin
COPY --from=builder /usr/sbin/kea-ctrl-agent /usr/sbin
COPY --from=builder /etc/kea/kea-dhcp4.conf /etc/kea
COPY --from=builder /usr/share/kea/scripts/ /usr/share/kea/scripts/
COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-dhcp4.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-shell.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-ctrl-agent.8 /usr/share/man/man8

# Copy configuration files.
COPY supervisor-agent-dhcp4.conf /etc/supervisor.conf
COPY kea-dhcp4.conf /etc/kea/
COPY agent-kea-ctrl-agent.conf /etc/kea-agent/kea-ctrl-agent.conf
COPY entrypoint-dhcp4.sh /agent/

ENV KEA_DATABASE_DELAY=10 \
    KEA_DATABASE_TYPE=mysql \
    KEA_DATABASE_HOST=mysql \
    KEA_DATABASE_PORT=3306 \
    KEA_DATABASE_NAME=kea \
    KEA_DATABASE_USER_NAME=kea \
    KEA_DATABASE_SSLMODE= \
    KEA_DATABASE_PASSWORD=kea

# Initialize the backends and start the supervisor.
ENTRYPOINT ["bash", "/agent/entrypoint-dhcp4.sh" ]

FROM debian:10-slim as isc-kea-dhcp6-server
LABEL maintainer="serhiy.makarenko@me.com"

ARG DEBIAN_FRONTEND=noninteractive
ADD *.gpg /etc/apt/trusted.gpg.d/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y ca-certificates apt-transport-https \
        supervisor prometheus-node-exporter net-tools iputils-ping mariadb-client \
        liblog4cplus-1.1-9 libssl1.1 libboost-system1.67.0 libmariadb3 libpq5 && \
    echo "deb [arch=amd64] https://dl.cloudsmith.io/public/isc/stork/deb/debian buster main" >> /etc/apt/sources.list.d/isc-stork.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests isc-stork-agent && \
    rm -rf /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /var/run/kea && mkdir /var/lib/kea && mkdir /etc/kea

COPY --from=builder /usr/lib/isc-kea-common-libs /usr/lib/
COPY --from=builder /usr/lib/kea/hooks/isc-kea-common-hooks /usr/lib/kea/hooks
COPY --from=builder /usr/sbin/kea-admin /usr/sbin
COPY --from=builder /usr/sbin/kea-lfc /usr/sbin
COPY --from=builder /usr/sbin/kea-dhcp6 /usr/sbin
COPY --from=builder /usr/sbin/kea-ctrl-agent /usr/sbin
COPY --from=builder /etc/kea/kea-dhcp6.conf /etc/kea
COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-dhcp6.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-shell.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-ctrl-agent.8 /usr/share/man/man8

# Copy configuration files.
COPY supervisor-agent-dhcp6.conf /etc/supervisor.conf
COPY kea-dhcp6.conf /etc/kea/
COPY agent-kea-ctrl-agent.conf /etc/kea-agent/kea-ctrl-agent.conf
COPY entrypoint-dhcp6.sh /agent/

ENV KEA_DATABASE_DELAY=10 \
    KEA_DATABASE_TYPE=mysql \
    KEA_DATABASE_HOST=mysql \
    KEA_DATABASE_PORT=3306 \
    KEA_DATABASE_NAME=kea \
    KEA_DATABASE_USER_NAME=kea \
    KEA_DATABASE_SSLMODE= \
    KEA_DATABASE_PASSWORD=kea

# Initialize the backends and start the supervisor.
ENTRYPOINT ["bash", "/agent/entrypoint-dhcp6.sh" ]


FROM debian:10-slim as isc-kea-full
LABEL maintainer="serhiy.makarenko@me.com"

ARG DEBIAN_FRONTEND=noninteractive
ADD *.gpg /etc/apt/trusted.gpg.d/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y ca-certificates apt-transport-https \
        supervisor prometheus-node-exporter net-tools iputils-ping mariadb-client \
        liblog4cplus-1.1-9 libssl1.1 libboost-system1.67.0 libmariadb3 libpq5 && \
    echo "deb [arch=amd64] https://dl.cloudsmith.io/public/isc/stork/deb/debian buster main" >> /etc/apt/sources.list.d/isc-stork.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests isc-stork-agent && \
    rm -rf /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /var/run/kea && mkdir /var/lib/kea && mkdir /etc/kea

COPY --from=builder /usr/lib/isc-kea-common-libs /usr/lib/
COPY --from=builder /usr/lib/kea/hooks/isc-kea-common-hooks /usr/lib/kea/hooks
COPY --from=builder /usr/sbin/kea-admin /usr/sbin
COPY --from=builder /usr/sbin/kea-lfc /usr/sbin
COPY --from=builder /usr/sbin/kea-ctrl-agent /usr/sbin
COPY --from=builder /usr/sbin/kea-dhcp6 /usr/sbin
COPY --from=builder /usr/sbin/kea-dhcp4 /usr/sbin
COPY --from=builder /etc/kea/kea-dhcp4.conf /etc/kea
COPY --from=builder /etc/kea/kea-dhcp6.conf /etc/kea
COPY --from=builder /usr/share/man/man8/kea-dhcp4.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-dhcp6.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-lfc.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-shell.8 /usr/share/man/man8
COPY --from=builder /usr/share/man/man8/kea-ctrl-agent.8 /usr/share/man/man8
COPY --from=builder /usr/sbin/kea-dhcp-ddns /usr/sbin
COPY --from=builder /etc/kea/kea-dhcp-ddns.conf /etc/kea
COPY --from=builder /usr/share/man/man8/kea-dhcp-ddns.8 /usr/share/man/man8

# Copy configuration files.
COPY supervisor-agent-full.conf /etc/supervisor.conf
COPY kea-dhcp4.conf /etc/kea/
COPY kea-dhcp6.conf /etc/kea/
COPY kea-dhcp-ddns.conf /etc/kea/
COPY agent-kea-ctrl-agent.conf /etc/kea-agent/kea-ctrl-agent.conf
COPY entrypoint-full.sh /agent/

ENV KEA_DATABASE_DELAY=10 \
    KEA_DATABASE_TYPE=mysql \
    KEA_DATABASE_HOST=mysql \
    KEA_DATABASE_PORT=3306 \
    KEA_DATABASE_NAME=kea \
    KEA_DATABASE_USER_NAME=kea \
    KEA_DATABASE_SSLMODE= \
    KEA_DATABASE_PASSWORD=kea

# Initialize the backends and start the supervisor.
ENTRYPOINT ["bash", "/agent/entrypoint-full.sh" ]

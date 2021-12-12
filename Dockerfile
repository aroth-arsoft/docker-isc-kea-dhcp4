FROM ubuntu:focal
MAINTAINER Andreas Roth "aroth@arsoft-online.com"
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.license=GPL-3.0 \
    org.label-schema.name=stork \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url=https://github.com/aroth-arsoft/docker-stork

ADD *.gpg /etc/apt/trusted.gpg.d/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y ca-certificates apt-transport-https supervisor prometheus-node-exporter net-tools iputils-ping mysql-client && \
    echo "deb [arch=amd64] https://dl.cloudsmith.io/public/isc/kea-2-0/deb/ubuntu focal main" >> /etc/apt/sources.list.d/isc-kea.list && \
    echo "deb [arch=amd64] https://dl.cloudsmith.io/public/isc/stork/deb/ubuntu focal main" >> /etc/apt/sources.list.d/isc-stork.list && \
    apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y isc-kea-dhcp4-server isc-kea-ctrl-agent isc-kea-admin && \
    apt-get clean && \
    mkdir -p /var/run/kea/ && \
    rm -rf /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Tell CA to listen on all interfaces.
RUN perl -pi -e 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/kea/kea-ctrl-agent.conf && \
    mkdir -p /var/lib/stork-agent/certs /var/lib/stork-agent/tokens
# Copy configuration files.
COPY supervisor-agent-kea.conf /etc/supervisor.conf
COPY kea-dhcp4.conf /etc/kea/
COPY agent-kea-ctrl-agent.conf /etc/kea/kea-ctrl-agent.conf
COPY *.sh /agent/

ENV KEA_DATABASE_DELAY=10 \
    KEA_DATABASE_TYPE=mysql \
    KEA_DATABASE_HOST=mysql \
    KEA_DATABASE_PORT=3306 \
    KEA_DATABASE_NAME=kea \
    KEA_DATABASE_USER_NAME=kea \
    KEA_DATABASE_SSLMODE= \
    KEA_DATABASE_PASSWORD=kea

# Initialize the backends and start the supervisor.
ENTRYPOINT ["bash", "/agent/entrypoint.sh" ]


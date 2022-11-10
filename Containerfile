# syntax=docker/dockerfile:1

# Build stage
FROM registry.fedoraproject.org/fedora:37 AS build

ARG PGBOUNCER_VERSION="1.17.0"
ARG PGBOUNCER_BUILD_OPTS="--with-cares"

RUN set -ex; \
      dnf install -y openssl-devel make pkgconf-pkg-config c-ares-devel pam-devel gcc libevent-devel;

WORKDIR /build

RUN set -ex; \
      curl -o /tmp/pgbouncer-${PGBOUNCER_VERSION}.tar.gz -L https://www.pgbouncer.org/downloads/files/${PGBOUNCER_VERSION}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz; \
      tar xvfz /tmp/pgbouncer-${PGBOUNCER_VERSION}.tar.gz -C /build --strip-components=1; \
      ./configure --prefix=/usr ${PGBOUNCER_BUILD_OPTS}; \
      make;
 
# Final stage
FROM registry.fedoraproject.org/fedora-minimal:37

RUN set -ex; \
      microdnf install -y shadow-utils c-ares; \
      microdnf clean all; \
      rm -rf /var/cache/dnf/*;

RUN set -ex; \
      groupadd -r --gid=27 pgbouncer; \
      useradd -r --uid=27 -g pgbouncer --create-home --shell=/bin/bash pgbouncer;

RUN set -ex; \
      mkdir -p /etc/pgbouncer /var/run/pgbouncer; \
      touch /etc/pgbouncer/userlist.txt; \
      chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/run/pgbouncer;

COPY --from=build /build/pgbouncer /usr/bin/pgbouncer
COPY --from=build  --chown=27:27 --chmod=700 /build/etc/mkauth.py /etc/pgbouncer/mkauth.py
COPY --chown=27:27 --chmod=600 config/pgbouncer.ini.default /etc/pgbouncer/pgbouncer.ini

USER pgbouncer

EXPOSE 6432

CMD [ "/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini" ]

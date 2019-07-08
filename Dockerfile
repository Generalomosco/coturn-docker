FROM alpine:latest

ENV COTURN_VERSION 4.5.1.1


RUN mkdir /src

RUN set -x && \
 apk update \
 && apk upgrade \
 && apk add --no-cache \
        ca-certificates \
        curl \
 && update-ca-certificates \
    \
 # Install Coturn dependencies
 && apk add --no-cache \
        libevent \
        gettext libcrypto1.1 libssl1.1 jq \
        libpq mariadb-connector-c sqlite-libs \
        hiredis \
        build-base automake autoconf readline \
        # mongo-c-driver dependencies
        snappy zlib \
    \
 # Install tools for building
 && apk add --no-cache --virtual .tool-deps \
        coreutils autoconf g++ libtool make \
        # mongo-c-driver building dependencies
        cmake \
    \
 # Install Coturn build dependencies
 && apk add --no-cache --virtual .build-deps \
        linux-headers \
        libevent-dev \
        readline-dev \
        openssl-dev \
        postgresql-dev mariadb-connector-c-dev sqlite-dev \
        hiredis-dev \
        # mongo-c-driver build dependencies
        snappy-dev zlib-dev \
    \
 # Download and prepare mongo-c-driver sources
 && curl -fL -o /tmp/mongo-c-driver.tar.gz \
             https://github.com/mongodb/mongo-c-driver/archive/1.14.0.tar.gz \
 && tar -xzf /tmp/mongo-c-driver.tar.gz -C /tmp/ \
 && cd /tmp/mongo-c-driver-* \
 # Build mongo-c-driver from sources
 # https://git.alpinelinux.org/aports/tree/non-free/mongo-c-driver/APKBUILD
 && mkdir -p /tmp/build/mongo-c-driver/ && cd /tmp/build/mongo-c-driver/ \
 && cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_INSTALL_LIBDIR=lib \
          -DENABLE_BSON:STRING=ON \
          -DENABLE_MONGOC:BOOL=ON \
          -DENABLE_SSL:STRING=OPENSSL \
          -DENABLE_AUTOMATIC_INIT_AND_CLEANUP:BOOL=OFF \
          -DENABLE_MAN_PAGES:BOOL=OFF \
          -DENABLE_TESTS:BOOL=ON \
          -DENABLE_EXAMPLES:BOOL=OFF \
          -DCMAKE_SKIP_RPATH=ON \
        /tmp/mongo-c-driver-* \
 && make \
 # Check mongo-c-driver build
 && MONGOC_TEST_SKIP_MOCK=on \
    MONGOC_TEST_SKIP_SLOW=on \
    MONGOC_TEST_SKIP_LIVE=on \
    make check \
    \
 # Install mongo-c-driver
 && make install

WORKDIR /src

RUN set -x && \
  wget --no-check-certificate https://github.com/coturn/coturn/archive/${COTURN_VERSION}.tar.gz && \
  tar zxf ${COTURN_VERSION}.tar.gz && \
  rm ${COTURN_VERSION}.tar.gz

WORKDIR /src/coturn-${COTURN_VERSION}
RUN set -x && \
    ./configure && \
    make install && \
    apk del .tool-deps .build-deps \
    && rm -rf /src && \
    rm -rf /var/cache/apk/* \
           /tmp/*

# STUN/TURN UDP
EXPOSE 3478/udp
# STUN/TURN TCP
EXPOSE 3478/tcp
# STUN/TURN UDP Alt port (RFC5780 support)
EXPOSE 3479/udp
# STUN/TURN TCP Alt port (RFC5780 support)
EXPOSE 3479/tcp
# STUN/TURN DTLS
EXPOSE 5349/udp
# STUN/TURN TLS
EXPOSE 5349/tcp
# STUN/TURN DTLS Alt port (RFC5780 support)
EXPOSE 5350/udp
# STUN/TURN TLS Alt port (RFC5780 support)
EXPOSE 5350/tcp
# UDP media ports for TURN relay
EXPOSE 20000-65535/udp

COPY rootfs /

RUN chmod u+rx /usr/local/bin/coturn.sh

CMD ["coturn.sh"]

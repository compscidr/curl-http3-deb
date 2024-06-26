FROM ubuntu:24.04 as prereqs
# based on the ngtcp2 version at https://curl.se/docs/http3.html
LABEL maintainer="ernstjason1@gmail.com"

RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    xz-utils \
    checkinstall \
    git \
    cmake \
    make \
    g++ \
    gcc \
    automake \
    libtool \
    pkg-config\
    && apt-get update -qq && apt-get clean

# openssl
FROM prereqs as build
WORKDIR /usr/src/
RUN git clone --depth 1 -b openssl-3.0.0+quic https://github.com/quictls/openssl
WORKDIR /usr/src/openssl
RUN ./config enable-tls1_3 --prefix=/usr/local/ssl --openssldir=/usr/local/ssl
RUN make
RUN checkinstall --addso=yes -D --install=yes -y --pkgname=openssl --pkgversion=$(git branch | sed -n 's/* openssl-//p')-jammy \
    --pkglicense="See upstream" --pakdir=/ --maintainer="Jason Ernst" --nodoc --backup=no

# nghttp3
WORKDIR /usr/src/
RUN git clone https://github.com/ngtcp2/nghttp3
WORKDIR /usr/src/nghttp3
RUN autoreconf -fi -I /usr/share/aclocal/ # https://github.com/nghttp2/nghttp2/issues/620#issuecomment-244531257
RUN ./configure --prefix=/usr/local/nghttp3 --enable-lib-only
RUN make
RUN checkinstall --addso=yes -D --install=yes -y --pkgname=nghttp3 --pkgversion=$(git describe --tags | cut -c2-)-jammy \
    --pkglicense="See upstream" --pakdir=/ --maintainer="Jason Ernst" --nodoc --backup=no

# ngtcp2
WORKDIR /usr/src/
RUN git clone https://github.com/ngtcp2/ngtcp2
WORKDIR /usr/src/ngtcp2
RUN autoreconf -fi
RUN ./configure PKG_CONFIG_PATH=/usr/local/ssl/lib64/pkgconfig:/usr/local/nghttp3/lib64/pkgconfig \
    LDFLAGS="-Wl,-rpath,/usr/local/ssl/lib" --prefix=/usr/local/ngtcp2 --enable-lib-only
RUN checkinstall --addso=yes -D --install=yes -y --pkgname=ngtcp2 --pkgversion=$(git describe --tags --always | cut -c2-)-jammy \
    --pkglicense="See upstream" --pakdir=/ --maintainer="Jason Ernst" --nodoc --backup=no --requires="openssl,nghttp3"

# curl with quic
WORKDIR /usr/src/
RUN git clone https://github.com/curl/curl
WORKDIR /usr/src/curl
RUN autoreconf -fi
RUN LDFLAGS="-Wl,-rpath,/usr/local/ssl/lib64" \
    ./configure PKG_CONFIG_PATH=/usr/local/ssl/lib64/pkgconfig:/usr/local/nghttp3/lib64/pkgconfig:/usr/local/ngtcp2/lib64/pkgconfig \
    --with-openssl=/usr/local/ssl \
    --with-nghttp3=/usr/local/nghttp3 --with-ngtcp2=/usr/local/ngtcp2
RUN checkinstall --addso=yes -D --install=yes -y --pkgname=curl --pkgversion=$(git describe --tags | sed -n 's/curl-//p' | tr _ -)-jammy \
    --pkglicense="See upstream" --pakdir=/ --maintainer="Jason Ernst" --nodoc --backup=no --requires="openssl,nghttp3,ngtcp2"
RUN ls -la /

# final image with curl for dockerhub
FROM ubuntu:24.04 as curl
RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    && apt-get update -qq && apt-get clean
COPY --from=build /*.deb /
RUN dpkg -i /*openssl*.deb && dpkg -i /*nghttp3*.deb && dpkg -i /*ngtcp2*.deb && dpkg -i /*curl*.deb
ENTRYPOINT ["/usr/local/bin/curl"]

# just a step that publishes the deb files to gemfury
FROM ubuntu:24.04 as deploy
RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl \
    && apt-get update -qq && apt-get clean
COPY --from=build /*.deb /
RUN ls -la /
ARG GFKEY_PUSH
RUN test -n "${GFKEY_PUSH}" || (>&2 echo "GFKEY_PUSH build arg not set" && false)
RUN for f in /*.deb; do curl -F package=@/$f https://${GFKEY_PUSH}@push.fury.io/compscidr/; done
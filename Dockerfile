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
    pkg-config \
    && apt-get update -qq && apt-get clean \
    && update-ca-certificates

# openssl
FROM prereqs as build
WORKDIR /usr/src/
RUN git clone --depth 1 -b openssl-3.0.0+quic https://github.com/quictls/openssl || \
    git -c http.sslverify=false clone --depth 1 -b openssl-3.0.0+quic https://github.com/quictls/openssl
WORKDIR /usr/src/openssl
RUN ./config enable-tls1_3 --prefix=/usr/local/ssl --openssldir=/usr/local/ssl
RUN make
RUN make install_sw
RUN mkdir -p /tmp/openssl-deb/DEBIAN /tmp/openssl-deb/usr/local/ssl
RUN cp -r /usr/local/ssl/* /tmp/openssl-deb/usr/local/ssl/
RUN echo "Package: openssl\nVersion: $(git branch | sed -n 's/* openssl-//p')-jammy\nSection: libs\nPriority: optional\nArchitecture: amd64\nMaintainer: Jason Ernst <ernstjason1@gmail.com>\nDescription: OpenSSL with QUIC support\n Custom build of OpenSSL with QUIC support" > /tmp/openssl-deb/DEBIAN/control
RUN dpkg-deb --build /tmp/openssl-deb /openssl-$(git branch | sed -n 's/* openssl-//p')-jammy_amd64.deb

# nghttp3
WORKDIR /usr/src/
RUN git clone https://github.com/ngtcp2/nghttp3
WORKDIR /usr/src/nghttp3
RUN autoreconf -fi -I /usr/share/aclocal/ # https://github.com/nghttp2/nghttp2/issues/620#issuecomment-244531257
RUN ./configure --prefix=/usr/local/nghttp3 --enable-lib-only
RUN make
RUN make install
RUN mkdir -p /tmp/nghttp3-deb/DEBIAN /tmp/nghttp3-deb/usr/local/nghttp3
RUN cp -r /usr/local/nghttp3/* /tmp/nghttp3-deb/usr/local/nghttp3/
RUN echo "Package: nghttp3\nVersion: $(git describe --tags | cut -c2-)-jammy\nSection: libs\nPriority: optional\nArchitecture: amd64\nMaintainer: Jason Ernst <ernstjason1@gmail.com>\nDescription: nghttp3 HTTP/3 library\n HTTP/3 library for ngtcp2" > /tmp/nghttp3-deb/DEBIAN/control
RUN dpkg-deb --build /tmp/nghttp3-deb /nghttp3-$(git describe --tags | cut -c2-)-jammy_amd64.deb

# ngtcp2
WORKDIR /usr/src/
RUN git clone https://github.com/ngtcp2/ngtcp2
WORKDIR /usr/src/ngtcp2
RUN autoreconf -fi
RUN ./configure PKG_CONFIG_PATH=/usr/local/ssl/lib64/pkgconfig:/usr/local/nghttp3/lib64/pkgconfig \
    LDFLAGS="-Wl,-rpath,/usr/local/ssl/lib" --prefix=/usr/local/ngtcp2 --enable-lib-only
RUN make
RUN make install
RUN mkdir -p /tmp/ngtcp2-deb/DEBIAN /tmp/ngtcp2-deb/usr/local/ngtcp2
RUN cp -r /usr/local/ngtcp2/* /tmp/ngtcp2-deb/usr/local/ngtcp2/
RUN echo "Package: ngtcp2\nVersion: $(git describe --tags --always | cut -c2-)-jammy\nSection: libs\nPriority: optional\nArchitecture: amd64\nDepends: openssl, nghttp3\nMaintainer: Jason Ernst <ernstjason1@gmail.com>\nDescription: ngtcp2 QUIC library\n QUIC library implementation" > /tmp/ngtcp2-deb/DEBIAN/control
RUN dpkg-deb --build /tmp/ngtcp2-deb /ngtcp2-$(git describe --tags --always | cut -c2-)-jammy_amd64.deb

# curl with quic
WORKDIR /usr/src/
RUN git clone https://github.com/curl/curl
WORKDIR /usr/src/curl
RUN autoreconf -fi
RUN LDFLAGS="-Wl,-rpath,/usr/local/ssl/lib64" \
    ./configure PKG_CONFIG_PATH=/usr/local/ssl/lib64/pkgconfig:/usr/local/nghttp3/lib64/pkgconfig:/usr/local/ngtcp2/lib64/pkgconfig \
    --with-openssl=/usr/local/ssl \
    --with-nghttp3=/usr/local/nghttp3 --with-ngtcp2=/usr/local/ngtcp2
RUN make
RUN make install
RUN mkdir -p /tmp/curl-deb/DEBIAN /tmp/curl-deb/usr/local/bin /tmp/curl-deb/usr/local/lib /tmp/curl-deb/usr/local/include
RUN cp /usr/local/bin/curl* /tmp/curl-deb/usr/local/bin/ || true
RUN cp -r /usr/local/lib/libcurl* /tmp/curl-deb/usr/local/lib/ || true
RUN cp -r /usr/local/include/curl /tmp/curl-deb/usr/local/include/ || true
RUN echo "Package: curl\nVersion: $(git describe --tags | sed -n 's/curl-//p' | tr _ -)-jammy\nSection: web\nPriority: optional\nArchitecture: amd64\nDepends: openssl, nghttp3, ngtcp2\nMaintainer: Jason Ernst <ernstjason1@gmail.com>\nDescription: curl with HTTP/3 support\n curl command line tool and library with HTTP/3/QUIC support" > /tmp/curl-deb/DEBIAN/control
RUN dpkg-deb --build /tmp/curl-deb /curl-$(git describe --tags | sed -n 's/curl-//p' | tr _ -)-jammy_amd64.deb
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
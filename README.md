# curl-http3-deb
Wanted an easy way to install curl with http3 / quic support for Ubuntu
22.04, so made this repo.

Turned the instructions here: https://curl.se/docs/http3.html into a .deb
installer that can be installed on Ubuntu 22.04.

The instructions were added into a Dockerfile and install of running
`make install`, we use `checkinstall` to generate deb packages.

This is similar to https://github.com/yurymuski/curl-http3, but uses
`ngtcp2` and `nghttp3` instead of `quiche`.

## Installation Instructions

Add the following to /etc/apt/sources.list.d/compscidr.list:
```
deb [trusted=yes] https://apt.fury.io/compscidr/ /
```

Then run:
```
sudo apt update && sudo apt install \
    openssl=3.0.0+quic-jammy-1 \
    nghttp3=0.7.0-4-g8597ab3-jammy-1 \
    ngtcp2=0.9.0-14-gccb745e5-jammy-1 \
    curl=7-85-0-177-g0a652280c-jammy-1
```

Note, if you already have curl installed, you may need to remove it first. 
You may also get ssl warnings about downgrade. If you want you can try adding
`--allow-downgrades` to the `apt-install` but this could break things. 

I currently use this for a docker container, so its not going to break an
entire system, but seems to be working fine with a ubuntu22.04 container.

## TODO
- rename the package,so it doesn't conflict with the official curl package
- rename the curl binary so it doesn't conflict with the official curl package
- pin git repo's for the build to particular tagged releases

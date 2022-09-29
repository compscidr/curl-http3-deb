# curl-http3-deb
Wanted an easy way to install curl with http3 / quic support for Ubuntu
22.04, so made this repo.

Turned the instructions here: https://curl.se/docs/http3.html into a .deb
installer that can be installed on Ubuntu 22.04.

The instructions were added into a Dockerfile and install of running
`make install`, we use `checkinstall` to generate deb packages. The
dependencies should be setup correctly such that one should be able to
just install the curl package from the gemfury repo, and it should work.

## Installation Instructions

Add the following to /etc/apt/sources.list.d/compscidr.list:
```
deb [trusted=yes] https://apt.fury.io/compscidr/ /
```

Then run:
```
sudo apt update && sudo apt install curl
```

Note, if you already have curl installed, you may need to remove it first.

## TODO
- rename the package,so it doesn't conflict with the official curl package
- rename the curl binary so it doesn't conflict with the official curl package
- pin git repo's for the build to particular tagged releases
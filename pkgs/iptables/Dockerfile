### Build iptables, https://www.netfilter.org/projects/iptables/index.html
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
# RUN apt update && apt install -y make gcc bzip2 build-essential
RUN apk add make gcc bzip2 build-base linux-headers
ARG IPTABLES_VERSION
ARG SOURCE_PATH=/iptables-${IPTABLES_VERSION}
ADD assets${SOURCE_PATH}.tar.xz /
RUN cd ${SOURCE_PATH} && ./configure --prefix=/usr --mandir=/usr/man --disable-nftables --enable-static --disable-shared --disable-devel \
    && make LDFLAGS='-all-static' \
    && mkdir /pkg && make install DESTDIR=/pkg \
    && strip /pkg/usr/sbin/xtables-legacy-multi

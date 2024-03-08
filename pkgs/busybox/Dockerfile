### Build busybox, https://www.busybox.net/
FROM ubuntu:jammy as busybox
RUN apt update && apt install -y make gcc bzip2 build-essential
ARG BUSYBOX_VERSION
ARG SOURCE_PATH=/busybox-${BUSYBOX_VERSION}
ARG BUILD_PATH=/busybox_build
ADD assets/busybox-${BUSYBOX_VERSION}.tar.bz2 /
RUN mkdir ${BUILD_PATH} && cd ${SOURCE_PATH} && make O=${BUILD_PATH} defconfig \
    && cd ${BUILD_PATH} && sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && make -j4

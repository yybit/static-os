### Build busybox, https://www.busybox.net/
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
# RUN apt update && apt install -y make gcc bzip2 build-essential
RUN apk add make gcc bzip2 build-base linux-headers
ARG BUSYBOX_VERSION
ARG SOURCE_PATH=/busybox-${BUSYBOX_VERSION}
ARG BUILD_PATH=/busybox_build
ADD assets/busybox-${BUSYBOX_VERSION}.tar.bz2 /
RUN mkdir ${BUILD_PATH} && cd ${SOURCE_PATH} && make O=${BUILD_PATH} defconfig \
    && cd ${BUILD_PATH} && sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && make -j4

### Build linux kernel, https://www.kernel.org/
FROM ubuntu:jammy as linux
RUN apt update && apt install -y make gcc bzip2 build-essential
RUN apt install -y flex bison bc elfutils libelf-dev libncurses-dev
ARG LINUX_VERSION
ARG SOURCE_PATH=/linux-${LINUX_VERSION}
ARG BUILD_PATH=/linux_build
ADD assets${SOURCE_PATH}.tar.xz /
RUN mkdir ${BUILD_PATH} && cd ${SOURCE_PATH} && make O=${BUILD_PATH} allnoconfig
COPY conf/linux_build_config ${BUILD_PATH}/.config
RUN cd ${BUILD_PATH} && make -j4
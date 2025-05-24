### Build linux kernel, https://www.kernel.org/
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
# RUN apt update && apt install -y make gcc bzip2 build-essential
# RUN apt install -y flex bison bc elfutils libelf-dev libncurses-dev
RUN apk add make gcc bzip2 build-base linux-headers
RUN apk add flex bison bc elfutils elfutils-dev ncurses-dev 
ARG LINUX_VERSION
ARG SOURCE_PATH=/linux-${LINUX_VERSION}
ARG BUILD_PATH=/linux_build
ADD assets${SOURCE_PATH}.tar.xz /
RUN mkdir ${BUILD_PATH} && cd ${SOURCE_PATH} && make O=${BUILD_PATH} allnoconfig
COPY conf/linux_build_config ${BUILD_PATH}/.config
RUN cd ${BUILD_PATH} && make -j4
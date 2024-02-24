### Build busybox, https://www.busybox.net/
FROM ubuntu:jammy as busybox
RUN apt update && apt install -y make gcc bzip2 build-essential
ARG BUSYBOX_VERSION
ARG SOURCE_PATH=/busybox-${BUSYBOX_VERSION}
ARG BUILD_PATH=/busybox_build
ADD assets/busybox-${BUSYBOX_VERSION}.tar.bz2 /
RUN mkdir ${BUILD_PATH} && cd ${SOURCE_PATH} && make O=${BUILD_PATH} defconfig \
    && cd ${BUILD_PATH} && sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && make -j4

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

### Build iptables, https://www.netfilter.org/projects/iptables/index.html
FROM ubuntu:jammy as iptables
RUN apt update && apt install -y make gcc bzip2 build-essential
ARG IPTABLES_VERSION
ARG SOURCE_PATH=/iptables-${IPTABLES_VERSION}
ADD assets${SOURCE_PATH}.tar.xz /
RUN cd ${SOURCE_PATH} && ./configure --prefix=/usr --mandir=/usr/man --disable-nftables --enable-static --disable-shared --disable-devel \
    && make LDFLAGS='-all-static' \
    && mkdir /pkg && make install DESTDIR=/pkg \
    && strip /pkg/usr/sbin/xtables-legacy-multi

# Build openssh, https://www.openssh.com/
FROM ubuntu:jammy as openssh
RUN apt update && apt install -y make gcc bzip2 build-essential
ARG OUT_DIR=/out
RUN mkdir ${OUT_DIR}
ARG ZLIB_VERSION
ARG ZLIB_SOURCE_PATH=/zlib-${ZLIB_VERSION}
ADD assets${ZLIB_SOURCE_PATH}.tar.gz /
RUN cd ${ZLIB_SOURCE_PATH} && ./configure --prefix="${OUT_DIR}" --static && make && make install
ARG OPENSSL_VERSION
ARG OPENSSL_SOURCE_PATH=/openssl-${OPENSSL_VERSION}
ADD assets${OPENSSL_SOURCE_PATH}.tar.gz /
RUN cd ${OPENSSL_SOURCE_PATH} && ./config --prefix="${OUT_DIR}" no-shared && make && make install
RUN apt install -y autoconf
ARG OPENSSH_VERSION
ARG OPENSSH_SOURCE_PATH=/openssh-portable-${OPENSSH_VERSION}
ARG OPENSSH_OUT_DIR=/var/openssh
ADD assets${OPENSSH_SOURCE_PATH}.tar.gz /
RUN cd ${OPENSSH_SOURCE_PATH} \
    && export CPPFLAGS="-I${OUT_DIR}/include -L. -L${OUT_DIR}/lib -L${OUT_DIR}/lib64 -fPIC" \
    && export CFLAGS="-I${OUT_DIR}/include -L. -L${OUT_DIR}/lib -L${OUT_DIR}/lib64 -fPIC" \
    && export LDFLAGS="-static -L. -L${OUT_DIR}/lib -L${OUT_DIR}/lib64 -Lopenbsd-compat" \
    && autoreconf \
    && ./configure --prefix="${OPENSSH_OUT_DIR}" --with-privsep-user=nobody --with-privsep-path="${OPENSSH_OUT_DIR}/var/empty" \
    && make && make install

FROM ubuntu:jammy
RUN apt update && apt install -y make gcc bzip2 build-essential
RUN apt install -y parted kpartx grub2-common dosfstools
RUN apt install -y grub-pc
ARG ROOT_PATH=/rootfs
ARG RUNC_VERSION
ARG CNI_PLUGINS_VERSION
ARG CONTAINERD_VERSION
ARG NERDCTL_VERSION
ARG CACERT_VERSION
ARG ARCH
ARG ARCH_ALIAS
ARG ARCH_KERNEL
COPY --from=linux /linux_build/arch/${ARCH_KERNEL}/boot/bzImage ${ROOT_PATH}/boot/vmlinuz
COPY --from=busybox /busybox_build/busybox ${ROOT_PATH}/bin/busybox
COPY --chmod=755 assets/runc-${RUNC_VERSION}-${ARCH_ALIAS} ${ROOT_PATH}/sbin/runc
ADD assets/cni-plugins-linux-${ARCH_ALIAS}-v${CNI_PLUGINS_VERSION}.tgz ${ROOT_PATH}/opt/cni/bin
ADD assets/containerd-static-${CONTAINERD_VERSION}-linux-${ARCH_ALIAS}.tar.gz ${ROOT_PATH}/
ADD assets/nerdctl-${NERDCTL_VERSION}-linux-${ARCH_ALIAS}.tar.gz ${ROOT_PATH}/bin
COPY assets/cacert-${CACERT_VERSION}.cer ${ROOT_PATH}/etc/pki/tls/certs/ca-bundle.crt
RUN ${ROOT_PATH}/bin/busybox --install ${ROOT_PATH}/bin
COPY --from=iptables /pkg/usr/sbin/xtables-legacy-multi ${ROOT_PATH}/sbin/xtables-legacy-multi
RUN cd ${ROOT_PATH}/sbin && ln -s xtables-legacy-multi iptables && ln -s xtables-legacy-multi ip6tables
COPY --chmod=755 target/${ARCH}-unknown-linux-musl/release/static-init ${ROOT_PATH}/init
COPY --chmod=755 conf/udhcpc-default.script ${ROOT_PATH}/sbin/udhcpc-default.script
COPY --chmod=644 conf/grub.cfg ${ROOT_PATH}/boot/grub/grub.cfg
COPY --chmod=644 conf/resolv.conf ${ROOT_PATH}/etc/resolv.conf
COPY --chmod=644 conf/hostname ${ROOT_PATH}/etc/hostname
COPY --chmod=644 conf/hosts ${ROOT_PATH}/etc/hosts
COPY --chmod=644 conf/fstab ${ROOT_PATH}/etc/fstab
COPY --chmod=644 conf/sshd_config ${ROOT_PATH}/etc/sshd_config
COPY --chmod=644 conf/containerd_config.toml ${ROOT_PATH}/etc/containerd/config.toml
COPY --chmod=644 assets/openssh-server.tar ${ROOT_PATH}/opt/images/openssh-server.tar
COPY --chmod=644 assets/empty-image.tar ${ROOT_PATH}/opt/images/empty-image.tar
RUN cd ${ROOT_PATH} && mkdir -p dev sys proc var tmp run etc/cni var/cni && touch etc/passwd etc/group
COPY --from=openssh /var/openssh/bin/ ${ROOT_PATH}/bin/
COPY --from=openssh /var/openssh/sbin/ ${ROOT_PATH}/sbin/
COPY --chmod=644 conf/openssh-compose.yaml ${ROOT_PATH}/etc/openssh-compose.yaml
COPY --chmod=644 conf/lima-compose.yaml ${ROOT_PATH}/etc/lima-compose.yaml
COPY --chmod=644 conf/acpid.conf ${ROOT_PATH}/etc/acpid.conf
COPY --chmod=755 conf/power ${ROOT_PATH}/etc/acpi/power
FROM ubuntu:jammy
RUN apt update && apt install -y make gcc bzip2 build-essential
RUN apt install -y parted kpartx grub2-common dosfstools
RUN apt install -y grub-efi
ARG ROOT_PATH=/rootfs
ARG RUNC_VERSION
ARG CNI_PLUGINS_VERSION
ARG CONTAINERD_VERSION
ARG NERDCTL_VERSION
ARG CACERT_VERSION
ARG IPTABLES_VERSION
ARG OPENSSH_VERSION
ARG LINUX_VERSION
ARG BUSYBOX_VERSION
ARG ARCH
ARG ARCH_ALIAS
COPY assets/vmlinuz-${LINUX_VERSION}-${ARCH_ALIAS} ${ROOT_PATH}/boot/vmlinuz
COPY --chmod=755 assets/busybox-${BUSYBOX_VERSION}-${ARCH_ALIAS} ${ROOT_PATH}/bin/busybox
COPY --chmod=755 assets/runc-${RUNC_VERSION}-${ARCH_ALIAS} ${ROOT_PATH}/sbin/runc
ADD assets/cni-plugins-linux-${ARCH_ALIAS}-v${CNI_PLUGINS_VERSION}.tgz ${ROOT_PATH}/opt/cni/bin
ADD assets/containerd-static-${CONTAINERD_VERSION}-linux-${ARCH_ALIAS}.tar.gz ${ROOT_PATH}/
ADD assets/nerdctl-${NERDCTL_VERSION}-linux-${ARCH_ALIAS}.tar.gz ${ROOT_PATH}/bin
COPY assets/cacert-${CACERT_VERSION}.cer ${ROOT_PATH}/etc/pki/tls/certs/ca-bundle.crt
RUN ${ROOT_PATH}/bin/busybox --install ${ROOT_PATH}/bin
COPY --chmod=755 assets/iptables-${IPTABLES_VERSION}-${ARCH_ALIAS} ${ROOT_PATH}/sbin/xtables-legacy-multi
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
ADD assets/openssh-portable-${OPENSSH_VERSION}-${ARCH_ALIAS}.tar.gz ${ROOT_PATH}/
COPY --chmod=644 conf/openssh-compose.yaml ${ROOT_PATH}/etc/openssh-compose.yaml
COPY --chmod=644 conf/lima-compose.yaml ${ROOT_PATH}/etc/lima-compose.yaml
COPY --chmod=644 conf/acpid.conf ${ROOT_PATH}/etc/acpid.conf
COPY --chmod=755 conf/power ${ROOT_PATH}/etc/acpi/power
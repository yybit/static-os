BUSYBOX_VERSION=1.36.1
LINUX_VERSION=6.7.1
LINUX_MAJOR_VERSION=6
RUNC_VERSION=1.1.11
CNI_PLUGINS_VERSION=1.4.0
CONTAINERD_VERSION=1.7.12
NERDCTL_VERSION=1.7.3
CACERT_VERSION=2023-12-12
IPTABLES_VERSION=1.8.10
ZLIB_VERSION=1.3.1
OPENSSL_VERSION=3.2.1
OPENSSH_VERSION=V_9_6_P1

ARCH ?= $(shell uname -m)
ifeq ($(strip $(ARCH)),arm64)
ARCH = aarch64
endif
ARCH_ALIAS_x86_64 = amd64
ARCH_ALIAS_aarch64 = arm64
ARCH_ALIAS = $(shell echo "$(ARCH_ALIAS_$(ARCH))")
ARCH_KERNEL_x86_64 = x86
ARCH_KERNEL_aarch64 = arm64
ARCH_KERNEL = $(shell echo "$(ARCH_KERNEL_$(ARCH))")

DOCKER_CLI?=docker
BUILDER_TAG?=static-os/builder
RUST_MUSL_TAG?=static-os/rust-musl
OPENSSH_TAG?=static-os/openssh
IPTABLES_TAG?=static-os/iptables
KERNEL_TAG?=static-os/kernel
BUSYBOX_TAG?=static-os/busybox
BASE_IMAGE?=alpine:latest
RUSTUP_DIST_SERVER?=https://static.rust-lang.org

ifeq ($(shell uname -s),Darwin)
 QEMU_EFI_FIRMWARE=$(shell dirname $(shell dirname $(shell which qemu-system-$(ARCH))))/share/qemu/edk2-$(ARCH)-code.fd
else
# On Linux, use the OVMF firmware provided by the edk2 project
# TODO: architecture detection
 QEMU_EFI_FIRMWARE=/usr/share/edk2/x64/OVMF.4m.fd
endif

BIOS ?= uefi
ifeq ($(filter $(BIOS),uefi legacy),)
    $(error BIOS variable can only be set to uefi or legacy)
endif

OUT_IMG=example-$(ARCH)-${BIOS}.img

.PHONY: builder
builder: assets
	$(DOCKER_CLI) build -t $(BUILDER_TAG) \
	--build-arg BUSYBOX_VERSION=$(BUSYBOX_VERSION) \
	--build-arg LINUX_VERSION=$(LINUX_VERSION) \
	--build-arg RUNC_VERSION=$(RUNC_VERSION) \
	--build-arg CNI_PLUGINS_VERSION=$(CNI_PLUGINS_VERSION) \
	--build-arg CONTAINERD_VERSION=$(CONTAINERD_VERSION) \
	--build-arg NERDCTL_VERSION=$(NERDCTL_VERSION) \
	--build-arg CACERT_VERSION=$(CACERT_VERSION) \
	--build-arg IPTABLES_VERSION=$(IPTABLES_VERSION) \
	--build-arg ZLIB_VERSION=$(ZLIB_VERSION) \
	--build-arg OPENSSL_VERSION=$(OPENSSL_VERSION) \
	--build-arg OPENSSH_VERSION=$(OPENSSH_VERSION) \
	--build-arg ARCH=$(ARCH) \
	--build-arg ARCH_ALIAS=$(ARCH_ALIAS) \
	--build-arg ARCH_KERNEL=$(ARCH_KERNEL) \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--platform linux/$(ARCH_ALIAS) \
	.

target/$(ARCH)-unknown-linux-musl/release/static-init:
	$(DOCKER_CLI) build -t $(RUST_MUSL_TAG) \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--build-arg ARCH=$(ARCH) \
	--build-arg RUSTUP_DIST_SERVER=$(RUSTUP_DIST_SERVER) \
	--platform linux/$(ARCH_ALIAS) \
	pkgs/rust-musl
	$(DOCKER_CLI) run --rm -v ${PWD}:/app --platform linux/$(ARCH_ALIAS) $(RUST_MUSL_TAG) \
	cargo build --target $(ARCH)-unknown-linux-musl --release

.PHONY: img
img: builder
	$(DOCKER_CLI) run --privileged \
	-v ${PWD}:/static-os \
	-v /tmp/lima:/output \
	--platform linux/$(ARCH_ALIAS) \
	--rm $(BUILDER_TAG) \
	/static-os/mkimg.sh /rootfs /output/$(OUT_IMG) $(ARCH) $(BIOS)

.PHONY: run
run:
	@if [ "$(BIOS)" = "uefi" ]; then\
		qemu-system-$(ARCH) \
		-drive if=pflash,format=raw,readonly=on,file=$(QEMU_EFI_FIRMWARE) \
		-drive format=raw,file=/tmp/lima/$(OUT_IMG),if=virtio \
		-boot order=c,splash-time=0,menu=on \
		-net nic,model=virtio -net user,hostfwd=tcp::10022-:22 -m 1G -nographic; \
	else \
		qemu-system-$(ARCH) \
		-drive format=raw,file=/tmp/lima/$(OUT_IMG),if=virtio \
		-net nic,model=virtio -net user,hostfwd=tcp::10022-:22 -m 1G -nographic; \
    fi

.PHONY: lima
lima:
	Variant=base ARCH=$(ARCH) BIOS=$(BIOS) OUT_IMG=$(OUT_IMG) ./lima.sh

.PHONY: assets
assets: \
	assets/busybox-$(BUSYBOX_VERSION).tar.bz2 \
	assets/linux-$(LINUX_VERSION).tar.xz \
	assets/runc-$(RUNC_VERSION)-$(ARCH_ALIAS) \
	assets/cni-plugins-linux-$(ARCH_ALIAS)-v$(CNI_PLUGINS_VERSION).tgz \
	assets/containerd-static-$(CONTAINERD_VERSION)-linux-$(ARCH_ALIAS).tar.gz \
	assets/nerdctl-$(NERDCTL_VERSION)-linux-$(ARCH_ALIAS).tar.gz \
	assets/cacert-$(CACERT_VERSION).cer \
	assets/iptables-$(IPTABLES_VERSION).tar.xz \
	assets/empty-image.tar \
	assets/zlib-$(ZLIB_VERSION).tar.gz \
	assets/openssl-$(OPENSSL_VERSION).tar.gz \
	assets/openssh-portable-$(OPENSSH_VERSION).tar.gz \
	assets/openssh-portable-$(OPENSSH_VERSION)-$(ARCH_ALIAS).tar.gz \
	assets/iptables-$(IPTABLES_VERSION)-$(ARCH_ALIAS) \
	assets/vmlinuz-$(LINUX_VERSION)-$(ARCH_ALIAS) \
	assets/busybox-$(BUSYBOX_VERSION)-$(ARCH_ALIAS) \
	target/$(ARCH)-unknown-linux-musl/release/static-init

assets/busybox-$(BUSYBOX_VERSION).tar.bz2:
	curl -o $@ -L https://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

assets/linux-$(LINUX_VERSION).tar.xz:
	curl -o $@ -L https://cdn.kernel.org/pub/linux/kernel/v$(LINUX_MAJOR_VERSION).x/linux-$(LINUX_VERSION).tar.xz

assets/runc-$(RUNC_VERSION)-$(ARCH_ALIAS):
	curl -o $@ -L https://github.com/opencontainers/runc/releases/download/v$(RUNC_VERSION)/runc.$(ARCH_ALIAS)

assets/cni-plugins-linux-$(ARCH_ALIAS)-v$(CNI_PLUGINS_VERSION).tgz:
	curl -o $@ -L https://github.com/containernetworking/plugins/releases/download/v$(CNI_PLUGINS_VERSION)/cni-plugins-linux-$(ARCH_ALIAS)-v$(CNI_PLUGINS_VERSION).tgz

assets/containerd-static-$(CONTAINERD_VERSION)-linux-$(ARCH_ALIAS).tar.gz:
	curl -o $@ -L https://github.com/containerd/containerd/releases/download/v$(CONTAINERD_VERSION)/containerd-static-$(CONTAINERD_VERSION)-linux-$(ARCH_ALIAS).tar.gz

assets/nerdctl-$(NERDCTL_VERSION)-linux-$(ARCH_ALIAS).tar.gz:
	curl -o $@ -L https://github.com/containerd/nerdctl/releases/download/v$(NERDCTL_VERSION)/nerdctl-$(NERDCTL_VERSION)-linux-$(ARCH_ALIAS).tar.gz

assets/cacert-$(CACERT_VERSION).cer:
	curl -o $@ -L https://curl.se/ca/cacert-$(CACERT_VERSION).pem

assets/iptables-$(IPTABLES_VERSION).tar.xz:
	curl -o $@ -L https://www.netfilter.org/projects/iptables/files/iptables-$(IPTABLES_VERSION).tar.xz

assets/zlib-$(ZLIB_VERSION).tar.gz:
	curl -o $@ -L https://github.com/madler/zlib/releases/download/v$(ZLIB_VERSION)/zlib-$(ZLIB_VERSION).tar.gz

assets/openssl-$(OPENSSL_VERSION).tar.gz:
	curl -o $@ -L https://github.com/openssl/openssl/releases/download/openssl-$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION).tar.gz

assets/openssh-portable-$(OPENSSH_VERSION).tar.gz:
	curl -o $@ -L https://github.com/openssh/openssh-portable/archive/refs/tags/$(OPENSSH_VERSION).tar.gz

assets/empty-image.tar:
	$(DOCKER_CLI) build -t empty -f pkgs/empty/Dockerfile .
	$(DOCKER_CLI) save empty > $@

assets/openssh-server.tar:
	$(DOCKER_CLI) pull linuxserver/openssh-server:latest
	$(DOCKER_CLI) save linuxserver/openssh-server:latest > $@

.PHONY: openssh
openssh:
	$(DOCKER_CLI) build -t $(OPENSSH_TAG) \
	--build-arg ZLIB_VERSION=$(ZLIB_VERSION) \
	--build-arg OPENSSL_VERSION=$(OPENSSL_VERSION) \
	--build-arg OPENSSH_VERSION=$(OPENSSH_VERSION) \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--platform linux/$(ARCH_ALIAS) \
	-f pkgs/openssh/Dockerfile \
	.

assets/openssh-portable-$(OPENSSH_VERSION)-$(ARCH_ALIAS).tar.gz:
	$(DOCKER_CLI) run --rm -v ${PWD}:/app --platform linux/$(ARCH_ALIAS) $(OPENSSH_TAG) \
	sh -c 'cd /var/openssh && tar -zhcvf /app/$@ bin sbin'

.PHONY: iptables
iptables:
	$(DOCKER_CLI) build -t $(IPTABLES_TAG) \
	--build-arg IPTABLES_VERSION=$(IPTABLES_VERSION) \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--platform linux/$(ARCH_ALIAS) \
	-f pkgs/iptables/Dockerfile \
	.

assets/iptables-$(IPTABLES_VERSION)-$(ARCH_ALIAS):
	$(DOCKER_CLI) run --rm -v ${PWD}:/app --platform linux/$(ARCH_ALIAS) $(IPTABLES_TAG) \
	sh -c 'cp /pkg/usr/sbin/xtables-legacy-multi /app/$@'

.PHONY: kernel
kernel:
	$(DOCKER_CLI) build -t $(KERNEL_TAG) \
	--build-arg LINUX_VERSION=$(LINUX_VERSION) \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--platform linux/$(ARCH_ALIAS) \
	-f pkgs/kernel/Dockerfile \
	.

assets/vmlinuz-$(LINUX_VERSION)-$(ARCH_ALIAS):
	$(DOCKER_CLI) run --rm -v ${PWD}:/app --platform linux/$(ARCH_ALIAS) $(KERNEL_TAG) \
	cp /linux_build/arch/${ARCH_KERNEL}/boot/bzImage /app/$@

.PHONY: busybox
busybox:
	$(DOCKER_CLI) build -t $(BUSYBOX_TAG) \
	--build-arg BUSYBOX_VERSION=$(BUSYBOX_VERSION) \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--platform linux/$(ARCH_ALIAS) \
	-f pkgs/busybox/Dockerfile \
	.

assets/busybox-$(BUSYBOX_VERSION)-$(ARCH_ALIAS):
	$(DOCKER_CLI) run --rm -v ${PWD}:/app --platform linux/$(ARCH_ALIAS) $(BUSYBOX_TAG) \
	cp /busybox_build/busybox /app/$@

BUSYBOX_VERSION=1.36.1
LINUX_VERSION=6.7.1
LINUX_MAJOR_VERSION=$(firstword $(LINUX_VERSION))
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

DOCKER_CLI=docker
BUILDER_NAME=static-os-builder
BUILDER_VERSION=0.0.1
BUILDER_TAG=$(BUILDER_NAME):0.0.1-$(ARCH)

.PHONY: builder
builder: assets init
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
	--platform linux/$(ARCH_ALIAS) \
	.

.PHONY: init
init:
	cargo zigbuild --target $(ARCH)-unknown-linux-musl --release

.PHONY: img
img: builder
	$(DOCKER_CLI) run --privileged \
	-v ${PWD}:/static-os \
	-v /tmp/lima:/output \
	--platform linux/$(ARCH_ALIAS) \
	--rm $(BUILDER_TAG) \
	/static-os/mkimg.sh /rootfs /output/example-$(ARCH).img

.PHONY: run
run:
	qemu-system-$(ARCH) -drive format=raw,file=/tmp/lima/example-$(ARCH).img,index=0,media=disk,if=virtio \
	-net nic,model=virtio -net user,hostfwd=tcp::10022-:22 -m 1G -nographic

.PHONY: lima
lima:
	Variant=base ARCH=$(ARCH) ./lima.sh

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
	assets/openssh-portable-$(OPENSSH_VERSION).tar.gz

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

assets/openssh--portable-$(OPENSSH_VERSION).tar.gz:
	curl -o $@ -L https://github.com/openssh/openssh-portable/archive/refs/tags/$(OPENSSH_VERSION).tar.gz

assets/empty-image.tar:
	$(DOCKER_CLI) build -t empty -f Dockerfile_empty .
	$(DOCKER_CLI) save empty > $@
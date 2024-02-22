# Static OS

Static OS is a lightweight linux distro for hosting containers. The project is still in early development.

## Feature

* No library dependency, all binary are statically linked.
* Immutable root fs, /var is writable.
* Support multiple cpu arch. [WIP]
* Support kubernetes. [WIP]
* Atomic update, double partition flip. [WIP]
* API driven, declaration configuration. [WIP]

## Components

* Kernel
* CA Cert
* Busybox
* Iptables
* Runc
* CNI Plugins
* Containerd
* Nerdctl
* Openssh [optional]

## Usage

### Build disk image

```shell
# Use `docker` cli by default
make img
# Use a docker-compatible cli
make img DOCKER_CLI='lima sudo nerdctl'
```

### Run disk image with qemu

```shell
make run
```

### Run disk image with lima

```
make lima
limactl shell base
```

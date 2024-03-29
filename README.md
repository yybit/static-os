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
* Static init


## Usage

### Prepare

Before building image, [Docker](https://www.docker.com/) or [Nerdctl](https://github.com/containerd/nerdctl) need to be installed.
If you cross-compile the image，run this to support multiple platform. 
```shell
# docker or nerdctl
docker run --privileged --rm tonistiigi/binfmt --install all
```

### Build components

```shell
# Use `docker` cli by default
make kernel busybox iptables openssh
# Use a docker-compatible cli
make kernel busybox iptables openssh DOCKER_CLI='lima sudo nerdctl'
```

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

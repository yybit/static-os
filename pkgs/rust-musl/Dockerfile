ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN apk add rustup
ARG RUSTUP_DIST_SERVER
ENV RUSTUP_DIST_SERVER=${RUSTUP_DIST_SERVER}
ARG ARCH
RUN rustup-init -t ${ARCH}-unknown-linux-musl -y
RUN apk add build-base

ADD ./config.toml* /.cargo/
ENV PATH "$PATH:/root/.cargo/bin"
WORKDIR /app

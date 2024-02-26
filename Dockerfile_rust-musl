FROM rust:slim
ARG ARCH

RUN rustup target add ${ARCH}-unknown-linux-musl

WORKDIR /app

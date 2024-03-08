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
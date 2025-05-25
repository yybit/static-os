ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN apk add openssh sudo

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
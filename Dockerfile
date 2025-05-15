FROM alpine:3.19

LABEL maintainer="Ivan Buiko <ivan@buiko.com>"
LABEL description="Docker container for performing periodic backups to S3-compatible storage using GPG encryption."
LABEL version="1.0"

RUN apk add --no-cache \
        gpg \
        gpg-agent \
        aws-cli \
        curl \
        tini \
    && mkdir -p /root/.aws /aws /root/.gnupg /app \
    && chmod 700 /root/.gnupg

COPY entrypoint.sh /app/entrypoint.sh
COPY backup.sh /app/backup.sh

RUN chmod +x /app/entrypoint.sh /app/backup.sh

HEALTHCHECK --interval=5m --timeout=3s --retries=3 \
  CMD ps | grep -v grep | grep crond || exit 1


ENTRYPOINT ["/sbin/tini", "--", "/app/entrypoint.sh"]

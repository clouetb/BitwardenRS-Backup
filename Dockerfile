FROM rclone/rclone:1.54.0

LABEL "repository"="https://github.com/clouetb/BitwardenRS-Backup" \
  "homepage"="https://github.com/clouetb/BitwardenRS-Backup" \
  "maintainer"="Benoît Clouet"

COPY scripts/*.sh /app/

RUN chmod +x /app/*.sh \
  && apk add --no-cache bash sqlite p7zip heirloom-mailx tzdata

ENTRYPOINT ["/app/entrypoint.sh"]

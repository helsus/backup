#!/bin/sh
echo "creating crontab"
echo -e "$CRON_SCHEDULE /app/backup.sh\n" > /etc/crontabs/root
echo "starting crond"
crond -f

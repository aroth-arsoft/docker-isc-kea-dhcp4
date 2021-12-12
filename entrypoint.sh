#!/bin/bash

sleep ${KEA_DATABASE_DELAY}
bash /agent/agent-kea-db-init.sh
[ $? -ne 0 ] && exit $?

exec supervisord -c /etc/supervisor.conf

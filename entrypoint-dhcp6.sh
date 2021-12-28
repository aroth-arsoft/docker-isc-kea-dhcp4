#!/bin/bash

sleep ${KEA_DATABASE_DELAY}

if [ "${KEA_DATABASE_TYPE}" = 'pgsql' ]; then
    kea_database_type_full='postgresql'
else
    kea_database_type_full="${KEA_DATABASE_TYPE}"
fi

cat << EOF > /tmp/kea-common.json
    "loggers": [
        {
            "name": "kea-dhcp6",
            "output_options": [
                {
                    "output": "stdout",
                    "pattern": "%-5p %m\n"
                },
                {
                    "output": "/tmp/kea-dhcp6.log"
                }
            ],
            "severity": "DEBUG",
            "debuglevel": 0
        }
    ],
    "control-socket": {
        "socket-type": "unix",
        "socket-name": "/tmp/kea6-ctrl-socket"
    },
    "config-control": {
        "config-databases": [{
            "type": "${kea_database_type_full}",
            "name": "${KEA_DATABASE_NAME}",
            "user": "${KEA_DATABASE_USER_NAME}",
            "password": "${KEA_DATABASE_PASSWORD}",
            "host": "${KEA_DATABASE_HOST}",
            "port": ${KEA_DATABASE_PORT}
        }],
        "config-fetch-wait-time": 20
    },
    "hosts-database": {
        "type": "${kea_database_type_full}",
        "name": "${KEA_DATABASE_NAME}",
        "user": "${KEA_DATABASE_USER_NAME}",
        "password": "${KEA_DATABASE_PASSWORD}",
        "host": "${KEA_DATABASE_HOST}",
        "port": ${KEA_DATABASE_PORT}
    },
    "lease-database": {
        "type": "${kea_database_type_full}",
        "host": "${KEA_DATABASE_HOST}",
        "port": ${KEA_DATABASE_PORT},
        "name": "${KEA_DATABASE_NAME}",
        "user": "${KEA_DATABASE_USER_NAME}",
        "password": "${KEA_DATABASE_PASSWORD}"
    },
    "hooks-libraries": [
        {
          "library": "/usr/lib/kea/hooks/libdhcp_lease_cmds.so"
        },
        {
          "library": "/usr/lib/kea/hooks/libdhcp_stat_cmds.so"
        },
        # Premium hooks: https://github.com/isc-projects/kea/blob/master/doc/sphinx/arm/hooks.rst
#        {
#          "library": "/usr/lib/kea/hooks/libdhcp_host_cmds.so"
#        },
        {
          "library": "/usr/lib/kea/hooks/libdhcp_mysql_cb.so"
        }
    ],


EOF

echo "Checking if the ${KEA_DATABASE_TYPE} database ${KEA_DATABASE_NAME} exists on ${KEA_DATABASE_HOST}:${KEA_DATABASE_PORT}"
if [ "${KEA_DATABASE_TYPE}" = 'mysql' ]; then
    mysql --user=${KEA_DATABASE_USER_NAME} --password=${KEA_DATABASE_PASSWORD} --host=${KEA_DATABASE_HOST} ${KEA_DATABASE_NAME} -e "select * from schema_version"
    DB_OK=$?
elif [ "${KEA_DATABASE_TYPE}" = 'pgsql' ]; then
    echo "${KEA_DATABASE_HOST}:*:*:${KEA_DATABASE_USER_NAME}:${KEA_DATABASE_PASSWORD}" > ~/.pgpass
    chmod 600 ~/.pgpass
    psql --username=${KEA_DATABASE_USER_NAME} --no-password --host=${KEA_DATABASE_HOST} --dbname=${KEA_DATABASE_NAME} -c "select * from schema_version"
    DB_OK=$?
fi
if [ $DB_OK -eq 0 ]; then
    echo "Database apparently exists"
else
    echo "Initializing the ${KEA_DATABASE_TYPE} database ${KEA_DATABASE_NAME} on ${KEA_DATABASE_HOST}"
    if [ "${KEA_DATABASE_TYPE}" = 'mysql' ]; then
        mysql --user=${KEA_DATABASE_USER_NAME} --password=${KEA_DATABASE_PASSWORD} --host=${KEA_DATABASE_HOST} -e "CREATE DATABASE IF NOT EXISTS ${KEA_DATABASE_NAME}"
        DB_OK=$?
    elif [ "${KEA_DATABASE_TYPE}" = 'pgsql' ]; then
        echo "SELECT 'CREATE DATABASE ${KEA_DATABASE_NAME}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KEA_DATABASE_NAME}')\gexec" | psql --username=${KEA_DATABASE_USER_NAME} --no-password --host=${KEA_DATABASE_HOST}
        DB_OK=$?
    fi
    if [ $DB_OK -ne 0 ]; then
        echo "Failed to create database"
        exit 1
    fi

    kea-admin db-init ${KEA_DATABASE_TYPE} -u ${KEA_DATABASE_USER_NAME} -p ${KEA_DATABASE_PASSWORD} -n ${KEA_DATABASE_NAME} -h ${KEA_DATABASE_HOST}
    if [ $? -ne 0 ]; then
        echo "Failed to initialize database"
        exit 1
    fi
fi

exec supervisord -c /etc/supervisor.conf

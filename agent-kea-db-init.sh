#!/bin/bash

if [ "${KEA_DATABASE_TYPE}" = 'pgsql' ]; then
    kea_database_type_full='postgresql'
else
    kea_database_type_full="${KEA_DATABASE_TYPE}"
fi

cat << EOF > /tmp/kea-common.json
    "loggers": [
        {
            "name": "kea-dhcp4",
            "output_options": [
                {
                    "output": "stdout",
                    "pattern": "%-5p %m\n"
                },
                {
                    "output": "/tmp/kea-dhcp4.log"
                }
            ],
            "severity": "DEBUG",
            "debuglevel": 0
        }
    ],
    "control-socket": {
        "socket-type": "unix",
        "socket-name": "/tmp/kea4-ctrl-socket"
    },
    "config-control": {
        "config-databases": [{
            "type": "${kea_database_type_full}",
            "name": "${KEA_DATABASE_NAME}",
            "user": "${KEA_DATABASE_USER_NAME}",
            "password": "${KEA_DATABASE_PASSWORD}",
            "host": "${KEA_DATABASE_HOST}"
        }],
        "config-fetch-wait-time": 20
    },
    "lease-database": {
        "type": "${kea_database_type_full}",
        "host": "${KEA_DATABASE_HOST}",
        "name": "${KEA_DATABASE_NAME}",
        "user": "${KEA_DATABASE_USER_NAME}",
        "password": "${KEA_DATABASE_PASSWORD}"
    },

EOF

echo "Checking if the ${KEA_DATABASE_TYPE} database ${KEA_DATABASE_NAME} exists on ${KEA_DATABASE_HOST}"
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
    exit 0
fi

set -e

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

if [ "${KEA_DATABASE_TYPE}" = 'mysql' ]; then
    mysql --user=${KEA_DATABASE_USER_NAME} --password=${KEA_DATABASE_PASSWORD} --host=${KEA_DATABASE_HOST} ${KEA_DATABASE_NAME} <<EOF

delete from lease4;
insert into lease4(address, hwaddr, client_id, valid_lifetime, expire, subnet_id, fqdn_fwd, fqdn_rev, hostname, state) values (INET_ATON('192.0.2.1'), UNHEX('1f1e1f1e1f1e'), UNHEX('1f1e1f1e'), 3600, DATE_ADD(NOW(), INTERVAL 1 MONTH), 1, false, false, 'client-1.example.org', 0);
insert into lease4(address, hwaddr, valid_lifetime, expire, subnet_id, hostname, state) values (INET_ATON('192.0.2.2'), '', 3600, DATE_ADD(NOW(), INTERVAL 1 MONTH), 1, '', 1);

EOF
    DB_OK=$?
elif [ "${KEA_DATABASE_TYPE}" = 'pgsql' ]; then
    psql --username=${KEA_DATABASE_USER_NAME} --no-password --host=${KEA_DATABASE_HOST} ${KEA_DATABASE_NAME} <<EOF

delete from lease4;
insert into lease4(address, hwaddr, client_id, valid_lifetime, expire, subnet_id, fqdn_fwd, fqdn_rev, hostname, state) values (INET_ATON('192.0.2.1'), UNHEX('1f1e1f1e1f1e'), UNHEX('1f1e1f1e'), 3600, DATE_ADD(NOW(), INTERVAL 1 MONTH), 1, false, false, 'client-1.example.org', 0);
insert into lease4(address, hwaddr, valid_lifetime, expire, subnet_id, hostname, state) values (INET_ATON('192.0.2.2'), '', 3600, DATE_ADD(NOW(), INTERVAL 1 MONTH), 1, '', 1);

EOF
    DB_OK=$?
fi
if [ $DB_OK -ne 0 ]; then
    echo "Failed to populate lease4 table"
    exit 1
fi
exit 0


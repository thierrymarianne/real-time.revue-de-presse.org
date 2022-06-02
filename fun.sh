#!/usr/bin/env bash -Eeuo pipefail

function set_up() {
    apt-get update

    if [ -z "${WORKER_UID}" ]; then

        printf 'A %s is expected as %s ("%s" environment variable).%s' 'worker user uid' 'non-empty string' 'WORKER_UID' $'\n' 1>&2

        exit 1

    fi

    if [ -z "${WORKER_GID}" ]; then

        echo 'A %s is expected as %s ("%s" environment variable).%s' 'worker user uid' 'non-empty string' 'WORKER_GID' $'\n' 1>&2

        exit 1

    fi

    if [ $(cat /etc/group | grep "${WORKER_GID}" -c) -eq 0 ]; then
        groupadd \
            --gid "${WORKER_GID}" \
            service
    fi

    if [ $(cat /etc/passwd | grep "${WORKER_UID}" -c) -eq 0 ]; then
        useradd \
            --shell /usr/sbin/nologin \
            --uid ${WORKER_UID} \
            --gid ${WORKER_GID} \
            --no-user-group \
            --no-create-home \
            service
    fi

    chown -R ${WORKER_UID}:${WORKER_GID} /go/src/app
}
set_up

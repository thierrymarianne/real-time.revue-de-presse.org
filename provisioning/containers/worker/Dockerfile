FROM        golang:1.18-bullseye

ARG         WORKER="trends.example.org"
ARG         WORKER_UID=1000
ARG         WORKER_GID=101

COPY        --chown=${WORKER_UID}:${WORKER_GID} \
            . \
            /var/www/${WORKER}

COPY        --chown=${WORKER_UID}:${WORKER_GID} \
            ./config.firebase.json \
            /var/www/${WORKER}/config.firebase.json

COPY        --chown=${WORKER_UID}:${WORKER_GID} \
            ./config.json \
            /var/www/${WORKER}/config.json

COPY        --chown=${WORKER_UID}:${WORKER_GID} \
            ./provisioning/containers/_scripts \
            /scripts

COPY        --chown=${WORKER_UID}:${WORKER_GID} \
            ./provisioning/containers/_scripts/cmd-worker.sh \
            /start.sh

RUN         /bin/bash -c 'source /scripts/install-worker-requirements.sh'

USER        ${WORKER_UID}:${WORKER_GID}

WORKDIR     /var/www/${WORKER}

VOLUME      ["/scripts", "/var/www/shared", "/var/www/${WORKER}"]

ENTRYPOINT  ["/usr/bin/tini", "--"]

CMD         ["/start.sh"]
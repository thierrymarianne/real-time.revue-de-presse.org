FROM golang:1.15-buster

ARG     uid
ARG     gid

ENV     WORKER_UID=${uid}
ENV     WORKER_GID=${gid}
ENV     GOCACHE=/go/src/app/cache

COPY    .                                      /go/src/app
COPY    ./config.firebase.json                 /go/src/app/config.firebase.json
COPY    ./config.json                          /go/src/app/config.json

COPY    --chown=${WORKER_UID}:${WORKER_GID}    ./fun.sh /set_up.sh

RUN     /bin/bash -c 'source /set_up.sh'

USER    service

WORKDIR /go/src/app

RUN go get -d -v . && \
    go install -v . && \
    go build -o /go/src/app/bin/news-review-realtime-db



CMD ["bin/news-review-realtime-db"]

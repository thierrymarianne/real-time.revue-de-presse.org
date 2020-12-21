#!/bin/bash

function install_dependencies() {
    go get -u github.com/go-sql-driver/mysql
    go get -u cloud.google.com/go/compute/metadata
    go get -u golang.org/x/oauth2
    go get -u gopkg.in/zabawaba99/firego.v1
    go get -u github.com/ti/nasync
    go get -u github.com/remeh/sizedwaitgroup
}
alias install-deps='install_dependencies'

function build_application() {
    go build .
}
alias build-application='build_application'

function install_application() {
    go install github.com/daily-press-review-golang
}
alias install-application='install_application'

function migrate_publications() {
    local date
    date="${SINCE_DATE}"

    if [ -z "${date}" ];
    then
       echo 'Please pass a valid date e.g.'
       echo 'export SINCE_DATE=`date -I`'

       return 1
    fi

    local aggregate_id;
    aggregate_id=1;

    # Migrate statuses from the first aggregate
    ./daily-press-review-golang -aggregate-id=${aggregate_id} -since-date="${date}" -in-parallel=true
}
alias migrate-publications='migrate_publications'

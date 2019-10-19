#!/bin/bash

function install_dependencies() {
    if [ ! "$(which go >> /dev/null)" ];
    then
        echo 'Could not find go binary in $PATH';
        return 1
    fi

    go get -u github.com/go-sql-driver/mysql
    go get -u cloud.google.com/go/compute/metadata
    go get -u golang.org/x/oauth2
    go get -u gopkg.in/zabawaba99/firego.v1
    go get -u github.com/ti/nasync
}

function build_application() {
    go build github.com/devobs-realtime-database
}

function install_application() {
    go install github.com/devobs-realtime-database
}
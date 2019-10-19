#!/bin/bash

function download_golang() {
    local target_dir
    target_dir="${1}"

    local version='1.13.3.linux-amd64'

    if [ -z "${target_dir}" ];
    then
        echo 'Please pass a target dir as first argument'
        echo 'export TARGET_DIR=/usr/local && make download-golang'
        return 1
    fi

    local path
    path="/tmp/go${version}.tar.gz"
    if [ ! -e "${path}" ];
    then
      # @requires wget
      wget "https://dl.google.com/go/go${version}.tar.gz" \
      -O "${path}"
    fi

    echo "$(\cat "./bin/go${version}.asc") ${path}" | sha256sum -c &&
    tar -xvzf "${path}"

    if [ ! -d "${target_dir}" ];
    then
        mv go "${target_dir}"
    fi

    rm "${path}"
}

function install_dependencies() {
    if ! $(\which go >> /dev/null);
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
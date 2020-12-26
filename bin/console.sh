#!/bin/bash

function get_application_prefix() {
    echo 'devobs-realtime-database'
}

function get_container_name_for() {
    local target
    target="${1}"

    local application_prefix
    application_prefix="$(get_application_prefix)-"

    echo "${application_prefix}${target}"
}

function get_image_name_for() {
    local target
    target="${1}"

    local application_prefix
    application_prefix="$(get_application_prefix)-"

    echo "${application_prefix}${target}"
}

function get_docker_network() {
    if [ ! -z "${DEVOBS_NETWORK}" ]
    then
        echo "${DEVOBS_NETWORK}"
        return
    fi

    echo 'devobs-api'
}

function create_network() {
    local network
    network="$(get_docker_network)"
    /bin/bash -c 'docker network create '"${network}"
}

function get_network_option() {
    network='--network "'$(get_docker_network)'" '
    if [ ! -z "${NO_DOCKER_NETWORK}" ];
    then
        network=''
    fi

    echo "${network}";
}

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

function build_worker_container() {
    docker build -t "$(get_image_name_for "worker")" .
}

function run_worker_container() {
    local aggregate_id
    aggregate_id="${1}"

    local date
    date="${2}"

    if [ -z "${aggregate_id}" ];
    then
      echo 'Please provide a aggregated id as a first argument.'
      echo 'or export an environment variable e.g.'
      echo 'export AGGREGATE_ID=858'
      return 1
    fi

    if [ -z "${date}" ];
    then
      echo 'Please provide a valid date as a second argument'
      echo 'or export an environment variable e.g.'
      echo 'export SINCE_DATE=2019-12-25'
      return 1
    fi

    local container_name
    container_name=$(get_container_name_for "worker")

    # ensure no container is running under the same name
    docker ps -a | grep "${container_name}" | \
    awk '{print $1}' | tail -n1 | xargs -I{} docker rm -f {}

    local network_option
    network_option="$(get_network_option)"

    local image_name
    image_name=$(get_image_name_for "worker")

    local command
    command=$(cat << COMMAND
docker run -it \
--rm \
${network_option} \
--name ${container_name} \
${image_name} \
devobs-realtime-database \
-aggregate-id=${aggregate_id} \
-since-date=${date} \
-in-parallel=true
COMMAND
)

    echo 'About to run the following command "'${command}'"'
    /bin/bash -c "${command}"
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
    go get -u github.com/remeh/sizedwaitgroup
}

function build_application() {
    test -e ./devobs-realtime-database && rm ./devobs-realtime-database
    go build .
}

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
    go build -o ./bin
}
alias build-application='build_application'

function migrate_publications() {
    local date
    date="${SINCE_DATE}"

    if [ -z "${date}" ];
    then
       echo 'Please pass a valid date e.g.'
       echo 'export SINCE_DATE=`date -I`'

       return 1
    fi

    local publishers_list_id
    publishers_list_id="${PUBLISHERS_LIST_ID}"

    if [ -z "${publishers_list_id}" ];
    then
       echo 'Please pass a valid publishers list id e.g.'
       echo 'export PUBLISHERS_LIST_ID="89f6db28-4d4e-49dc-a2c6-b6bb0e7b12af"'

       return 1
    fi

    # Migrate statuses from the first aggregate
    ./bin/devobs-realtime-database -publishers-list-id="${publishers_list_id}" -since-date="${date}" -in-parallel=true
}
alias migrate-publications='migrate_publications'

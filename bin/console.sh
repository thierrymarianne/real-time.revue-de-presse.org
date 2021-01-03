#!/bin/bash

function get_application_prefix() {
    echo 'devobs-realtime-database'
}

function get_container_name_for() {
    local target
    target="${1}"

    local application_prefix
    application_prefix="$(get_application_prefix)-"

    local work_directory
    work_directory="$(pwd)"

    local suffix
    suffix="-$(echo "${work_directory}" | sha1sum | tail -c12 | awk '{print $1}')"

    echo "${application_prefix}${target}${suffix}"
}

function get_image_name_for() {
    local target
    target="${1}"

    local application_prefix
    application_prefix="$(get_application_prefix)-"

    local work_directory
    work_directory="$(pwd)"

    local suffix
    suffix="-$(echo "${work_directory}" | sha1sum | tail -c12 | awk '{print $1}')"

    echo "${application_prefix}${target}${suffix}"
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
    if [ -n "${NO_DOCKER_NETWORK}" ];
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
    local date
    date="${2}"

    local publishers_list_id
    publishers_list_id="${1}"

    if [ -z "${publishers_list_id}" ];
    then
        echo 'Please provide a aggregated id as a first argument.'
        echo 'or export an environment variable e.g.'
        echo 'export PUBLISHERS_LIST_ID="89f6db28-4d4e-49dc-a2c6-b6bb0e7b12af"'
        return 1
    fi

    if [ -z "${date}" ];
    then
        echo 'Please provide a valid date as a second argument'
        echo 'or export an environment variable e.g.'
        echo 'export SINCE_DATE=2019-12-25'
        return 1
    fi

    local suffix
    suffix="-$(echo "${publishers_list_id}-${date}" | sha1sum | tail -c12 | awk '{print $1}')"

    local container_name
    container_name=$(get_container_name_for "worker")"${suffix}"

    # ensure no container is running under the same name
    docker ps -a | grep "${container_name}" | \
    awk '{print $1}' | tail -n1 | xargs -I{} docker rm -f {}

    local network_option
    network_option="$(get_network_option)"

    local image_name
    image_name=$(get_image_name_for "worker")

    local command
    command=$(cat << COMMAND
docker run \
--rm \
${network_option} \
--name ${container_name} \
${image_name} \
bin/devobs-realtime-database \
-publishers-list-id="${publishers_list_id}" \
-since-date=${date} \
-in-parallel=true
COMMAND
)

    echo 'About to run the following command "'${command}'"'
    /bin/bash -c "${command}"
}

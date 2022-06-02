#!/usr/bin/env bash

set -Eeuo pipefail

function get_application_prefix() {
    echo 'news-review-realtime-db'
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
    if [ -z "${NEWS_REVIEW_NETWORK}" ]; then

        printf 'A %s is expected as %s("%s" environment variable).%s' 'non-empty string' 'network name' 'NEWS_REVIEW_NETWORK' $'\n' 1>&2

        return 1

    fi

    echo "${NEWS_REVIEW_NETWORK}"
}

function get_network_option() {
    local network_name
    network_name=$(get_docker_network)

    if [ $? -gt 0 ]; then

        return 1

    fi

    network='--network "'${network_name}'" '
    if [ -n "${NO_DOCKER_NETWORK}" ]; then
        network=''
    fi

    echo "${network}"
}

function download_golang() {
    local target_dir
    target_dir="${1}"

    local version='1.13.3.linux-amd64'

    if [ -z "${target_dir}" ]; then
        echo 'Please pass a target dir as first argument'
        echo 'export TARGET_DIR=/usr/local && make download-golang'
        return 1
    fi

    local file_path
    file_path="/tmp/go${version}.tar.gz"
    if [ ! -e "${path}" ]; then
        # @requires wget
        wget "https://dl.google.com/go/go${version}.tar.gz" \
            -O "${file_path}"
    fi

    echo "$(\cat "./bin/go${version}.asc") ${file_path}" | sha256sum -c - &&
        tar -xvzf "${file_path}"

    if [ -d "${target_dir}" ]; then
        mv go "${target_dir}"
    fi

    rm "${file_path}"
}

function build() {
    if [ -z "${uid}" ]; then

        printf 'A %s is expected as %s ("%s" environment variable).%s' 'worker user uid' 'non-empty string' 'uid' $'\n' 1>&2

        exit 1

    fi

    if [ -z "${gid}" ]; then

        printf 'A %s is expected as %s ("%s" environment variable).%s' 'worker user uid' 'non-empty string' 'gid' $'\n' 1>&2

        exit 1

    fi

    docker build \
        --build-arg="uid=${uid}" \
        --build-arg="gid=${gid}" \
        -t "$(get_image_name_for "worker")" .
}

function run_worker_container() {
    local date
    date="${2}"

    local publishers_list_id
    publishers_list_id="${1}"

    if [ -z "${publishers_list_id}" ]; then
        echo 'Please provide a aggregated id as a first argument.'
        echo 'or export an environment variable e.g.'
        echo 'export PUBLISHERS_LIST_ID="1"'
        return 1
    fi

    if [ -z "${date}" ]; then
        echo 'Please provide a valid date as a second argument'
        echo 'or export an environment variable e.g.'
        echo 'export SINCE_DATE=2019-12-25'
        return 1
    fi

    local container_name
    container_name=$(get_container_name_for "worker")

    # ensure no container is running under the same name
    docker ps -a | grep "${container_name}" |
        awk '{print $1}' | tail -n1 | xargs -I{} docker rm -f {}

    local network_option
    network_option="$(get_network_option)"

    if [ $? -gt 0 ]; then

        echo 'Could not figure which network to run container from.' 1>&2

        return 1:

    fi

    local image_name
    image_name=$(get_image_name_for "worker")

    local command
    command=$(
        cat <<-COMMAND
			docker run \
			--rm \
			${network_option} \
			--name ${container_name} \
			${image_name} \
			bin/news-review-realtime-db \
			-aggregate-id=${publishers_list_id} \
			-since-date=${date} \
			-in-parallel=true
COMMAND
    )

    echo 'About to run the following command "'${command}'"'
    /bin/bash -c "${command}"
}

set +Eeuo pipefail

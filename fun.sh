#!/usr/bin/env bash
set -Eeuo pipefail

function load_configuration_parameters() {
    if [ ! -e ./.env ]; then
        cp --verbose ./.env{.dist,}
    fi

    if [ ! -e ./config.json ]; then
        cp --verbose ./config.json{.dist,}
    fi

    if [ ! -e ./config.firebase.json ]; then
        cp --verbose ./config.firebase.json{.dist,}
    fi

    if [ ! -e ./provisioning/containers/docker-compose.override.yaml ]; then
        cp ./provisioning/containers/docker-compose.override.yaml{.dist,}
    fi

    validate_docker_compose_configuration

    source ./.env

    guard_against_missing_variables
}

function _set_file_permissions() {
    local temporary_directory
    temporary_directory="${1}"

    if [ -z "${temporary_directory}" ];
    then
        printf 'A %s is expected as %s (%s).%s' 'non-empty string' '1st argument' 'temporary directory file path' $'\n'

        return 1;
    fi

    if [ ! -d "${temporary_directory}" ];
    then
        printf 'A %s is expected as %s (%s).%s' 'directory' '1st argument' 'temporary directory file path' $'\n'

        return 1;
    fi

    docker compose \
        -f ./provisioning/containers/docker-compose.yaml \
        -f ./provisioning/containers/docker-compose.override.yaml \
        run \
        --rm \
        --user root \
        --volume "${temporary_directory}:/tmp/remove-me" \
        app \
        /bin/bash -c 'chmod -R ug+w /tmp/remove-me'
}

function build() {
    local COMPOSE_PROJECT_NAME
    local DEBUG
    local WORKER
    local WORKER_UID
    local WORKER_GID

    load_configuration_parameters

    if [ $? -gt 1 ];
    then

        printf '%s.%s' 'Invalid configuration files' $'\n' 1>&2

        return 1;

    fi

    if [ -n "${DEBUG}" ];
    then

        clean ''

        docker compose \
            --file=./provisioning/containers/docker-compose.yaml \
            --file=./provisioning/containers/docker-compose.override.yaml \
            build \
            --no-cache \
            --build-arg "WORKER_UID=${WORKER_UID}" \
            --build-arg "WORKER_GID=${WORKER_GID}" \
            --build-arg "WORKER=${WORKER}" \
            app \
            worker

    else

        docker compose \
            --file=./provisioning/containers/docker-compose.yaml \
            --file=./provisioning/containers/docker-compose.override.yaml \
            build \
            --build-arg "WORKER_UID=${WORKER_UID}" \
            --build-arg "WORKER_GID=${WORKER_GID}" \
            --build-arg "WORKER=${WORKER}" \
            app \
            worker

    fi
}

function guard_against_missing_variables() {
    if [ -z "${COMPOSE_PROJECT_NAME}" ];
    then

        printf 'A %s is expected as %s ("%s" environment variable).%s' 'non-empty string' 'project name e.g. org_example_trends' 'COMPOSE_PROJECT_NAME' $'\n'

        exit 1

    fi

    if [ "${COMPOSE_PROJECT_NAME}" = 'trends_example_org' ];
    then

        printf 'Have you picked a satisfying worker name ("%s" environment variable - "%s" default value is not accepted).%s' 'WORKER' 'trends_example_org' $'\n'

        exit 1

    fi

    if [ -z "${WORKER}" ];
    then

        printf 'A %s is expected as %s ("%s" environment variable).%s' 'non-empty string' 'worker name e.g. org.example.trends' 'WORKER' $'\n'

        exit 1

    fi

    if [ "${WORKER}" = 'org.example.trends' ];
    then

        printf 'Have you picked a satisfying worker name ("%s" environment variable - "%s" default value is not accepted).%s' 'WORKER' 'org.example.trends' $'\n'

        exit 1

    fi

    if [ -z "${WORKER_UID}" ];
    then

        printf 'A %s is expected as %s ("%s").%s' 'non-empty numeric' 'system user uid' 'WORKER_UID' $'\n'

        exit 1

    fi

    if [ -z "${WORKER_GID}" ];
    then

        printf 'A %s is expected as %s ("%s").%s' 'non-empty numeric' 'system user gid' 'WORKER_GID' $'\n'

        exit 1

    fi
}

function remove_running_container_and_image_in_debug_mode() {
    local container_name
    container_name="${1}"

    if [ -z "${container_name}" ];
    then

        printf 'A %s is expected as %s ("%s").%s' 'non-empty string' '1st argument' 'container name' $'\n'

        return 1

    fi

    local COMPOSE_PROJECT_NAME
    local DEBUG
    local WORKER_UID
    local WORKER_GID
    local WORKER

    load_configuration_parameters

    if [ $? -gt 1 ];
    then

        printf '%s.%s' 'Invalid configuration files' $'\n' 1>&2

        return 1;

    fi

    local project_name

    if [ -n "${COMPOSE_PROJECT_NAME}" ];
    then
        project_name="${COMPOSE_PROJECT_NAME}"
    else
        project_name="$(get_project_name)"
    fi

    cat <<- CMD
      docker ps -a |
      \grep "${project_name}" |
      \grep "${container_name}" |
      awk '{print \$1}' |
      xargs -I{} docker rm -f {}
CMD

    docker ps -a |
        \grep "${project_name}" |
        \grep "${container_name}" |
        awk '{print $1}' |
        xargs -I{} docker rm -f {}

    if [ -n "${DEBUG}" ];
    then

        cat <<- CMD
        docker images -a |
        \grep "${project_name}" |
        \grep "${container_name}" |
        awk '{print \$3}' |
        xargs -I{} docker rmi -f {}
CMD

        docker images -a |
            \grep "${project_name}" |
            \grep "${container_name}" |
            awk '{print $3}' |
            xargs -I{} docker rmi -f {}

    fi
}

function clean() {
    local temporary_directory
    temporary_directory="${1}"

    if [ -n "${temporary_directory}" ];
    then
        printf 'About to remove "%s".%s' "${temporary_directory}" $'\n'

        _set_file_permissions "${temporary_directory}"

        return 0
    fi

    remove_running_container_and_image_in_debug_mode 'app'
    remove_running_container_and_image_in_debug_mode 'worker'
}

function install() {
    local COMPOSE_PROJECT_NAME
    local DEBUG
    local WORKER_UID
    local WORKER_GID
    local WORKER

    load_configuration_parameters

    if [ $? -gt 1 ];
    then

        printf '%s.%s' 'Invalid configuration files' $'\n' 1>&2

        return 1;

    fi

    docker compose \
        -f ./provisioning/containers/docker-compose.yaml \
        -f ./provisioning/containers/docker-compose.override.yaml \
        run \
        --env WORKER_WORKSPACE="${WORKER}" \
        --user root \
        --rm \
        --no-TTY \
        app \
        /bin/bash -c 'source /scripts/install-app-requirements.sh'
}

function get_project_name() {
    local project_name
    project_name="$(
        docker compose \
        -f ./provisioning/containers/docker-compose.yaml \
        -f ./provisioning/containers/docker-compose.override.yaml \
        config --format json \
        | jq '.name' \
        | tr -d '"'
    )"

    echo "${project_name}"
}

function get_worker_shell() {
    if ! command -v jq >> /dev/null 2>&1;
    then
        printf 'Is %s (%s) installed?%s' 'command-line JSON processor' 'jq' $'\n'

        return 1
    fi

    local project_name
    project_name="$(get_project_name)"

    docker exec -ti "$(
        docker ps -a \
        | \grep "${project_name}" \
        | \grep 'worker' \
        | awk '{print $1}'
    )" bash
}

function start() {
    local COMPOSE_PROJECT_NAME
    local DEBUG
    local WORKER
    local WORKER_UID
    local WORKER_GID

    load_configuration_parameters

    if [ $? -gt 1 ];
    then

        printf '%s.%s' 'Invalid configuration files' $'\n' 1>&2

        return 1;

    fi

    local publishers_list_id
    publishers_list_id="${LIST_ID}"

    if [ -z "${publishers_list_id}" ];
    then

        publishers_list_id="${LIST_ID}"

    fi

    local date
    date="${DATE}"

    if [ -z "${date}" ];
    then

        date="$(date -I)"

    fi

    cmd="$(
        cat <<-START
				docker compose \
				--file=./provisioning/containers/docker-compose.yaml \
				--file=./provisioning/containers/docker-compose.override.yaml \
				run \
				--detach \
				--rm \
				worker \
				bash -c 'bin/trends -publishers-list-id="${publishers_list_id}" -since-date="${date}" -in-parallel=true'
START
)"

    echo -n "${cmd}"

    container_id="$(/bin/bash -c "${cmd}")"
    docker logs -f "${container_id}" >> "./var/log/${WORKER}.log" 2>> "./var/log/${WORKER}.error.log"
}

function stop() {
    guard_against_missing_variables

    remove_running_container_and_image_in_debug_mode 'worker'
}

function validate_docker_compose_configuration() {
    docker compose \
        -f ./provisioning/containers/docker-compose.yaml \
        -f ./provisioning/containers/docker-compose.override.yaml \
        config -q
}

set +Eeuo pipefail

#!/usr/bin/env bash
set -Eeuo pipefail

function green() {
    echo -n "\e[32m"
}

function reset_color() {
    echo -n $'\033'\[00m
}

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

    source ./.env

    validate_docker_compose_configuration
    guard_against_missing_variables

    printf '%s'           $'\n'
    printf '%b%s%b"%s"%s' "$(green)" 'COMPOSE_PROJECT_NAME: ' "$(reset_color)" "${COMPOSE_PROJECT_NAME}" $'\n'
    printf '%b%s%b"%s"%s' "$(green)" 'DEBUG:                ' "$(reset_color)" "${DEBUG}" $'\n'
    printf '%b%s%b"%s"%s' "$(green)" 'WORKER_DIR:           ' "$(reset_color)" "${WORKER}" $'\n'
    printf '%b%s%b"%s"%s' "$(green)" 'WORKER_OWNER_UID:     ' "$(reset_color)" "${WORKER_OWNER_UID}" $'\n'
    printf '%b%s%b"%s"%s' "$(green)" 'WORKER_OWNER_GID:     ' "$(reset_color)" "${WORKER_OWNER_GID}" $'\n'
    printf '%s'           $'\n'
}

function set_file_permissions() {
    load_configuration_parameters

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

    local project_name
    project_name="$(get_project_name)"

    docker compose \
        --project-name="${project_name}" \
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
    local WORKER_OWNER_UID
    local WORKER_OWNER_GID

    load_configuration_parameters

    if [ $? -gt 1 ];
    then

        printf '%s.%s' 'Invalid configuration files' $'\n' 1>&2

        return 1;

    fi

    local project_name
    project_name="$(get_project_name)"

    if [ -n "${DEBUG}" ];
    then

        clean ''

        docker compose \
            --project-name="${project_name}" \
            --file=./provisioning/containers/docker-compose.yaml \
            --file=./provisioning/containers/docker-compose.override.yaml \
            build \
            --no-cache \
            --build-arg "OWNER_UID=${WORKER_OWNER_UID}" \
            --build-arg "OWNER_GID=${WORKER_OWNER_GID}" \
            --build-arg "WORKER=${WORKER}" \
            app \
            worker

    else

        docker compose \
            --project-name="${project_name}" \
            --file=./provisioning/containers/docker-compose.yaml \
            --file=./provisioning/containers/docker-compose.override.yaml \
            build \
            --no-cache \
            --build-arg "OWNER_UID=${WORKER_OWNER_UID}" \
            --build-arg "OWNER_GID=${WORKER_OWNER_GID}" \
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

    if [ "${COMPOSE_PROJECT_NAME}" = 'org_example_trends' ];
    then

        printf 'Have you picked a satisfying worker name ("%s" environment variable - "%s" default value is not accepted).%s' 'WORKER' 'org_example_trends' $'\n'

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

    if [ -z "${WORKER_OWNER_UID}" ];
    then

        printf 'A %s is expected as %s ("%s").%s' 'non-empty numeric' 'system user uid' 'WORKER_OWNER_UID' $'\n'

        exit 1

    fi

    if [ -z "${WORKER_OWNER_GID}" ];
    then

        printf 'A %s is expected as %s ("%s").%s' 'non-empty numeric' 'system user gid' 'WORKER_OWNER_GID' $'\n'

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
    local WORKER_OWNER_UID
    local WORKER_OWNER_GID
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
        printf 'About to revise file permissions for "%s" before clean up.%s' "${temporary_directory}" $'\n'

        set_file_permissions "${temporary_directory}"

        return 0
    fi

    remove_running_container_and_image_in_debug_mode 'app'
    remove_running_container_and_image_in_debug_mode 'worker'
}

function install() {
    local COMPOSE_PROJECT_NAME
    local DEBUG
    local WORKER_OWNER_UID
    local WORKER_OWNER_GID
    local WORKER

    load_configuration_parameters

    if [ $? -gt 1 ];
    then

        printf '%s.%s' 'Invalid configuration files' $'\n' 1>&2

        return 1;

    fi

    docker compose \
        --project-name="${project_name}" \
        -f ./provisioning/containers/docker-compose.yaml \
        -f ./provisioning/containers/docker-compose.override.yaml \
        run \
        --env WORKER="${WORKER}" \
        --user root \
        --rm \
        --no-TTY \
        app \
        /bin/bash -c 'source /scripts/install-app-requirements.sh'
}

function get_project_name() {
    if [ -z "${COMPOSE_PROJECT_NAME}" ];
    then

      printf 'A %s is expected as %s ("%s").%s' 'non-empty string' '"COMPOSE_PROJECT_NAME" environment variable' 'docker compose project name' $'\n'

      return 1;

    fi

    echo "${COMPOSE_PROJECT_NAME}"
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
    local WORKER_OWNER_UID
    local WORKER_OWNER_GID

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

    local from_distinct_sources
    from_distinct_sources='false'

    if [ -n "${FROM_DISTINCT_SOURCES_ONLY}" ];
    then

        from_distinct_sources='true'

    fi

    local project_name
    project_name="$(get_project_name)"

    cmd="$(
        cat <<-START
				docker compose \
          --project-name="${project_name}" \
          --file=./provisioning/containers/docker-compose.yaml \
          --file=./provisioning/containers/docker-compose.override.yaml \
          run \
          --rm \
          worker \
          bash -c 'bin/trends -publishers-list-id="${publishers_list_id}" -migrate-distinct-sources-only=${from_distinct_sources} -since-date="${date}" -in-parallel=true'
START
)"

    printf '%s%s' "${cmd}" $'\n' >> "./var/log/${WORKER}.log"

    /bin/bash -c "${cmd}" >> "./var/log/${WORKER}.log" 2>> "./var/log/${WORKER}.error.log"
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

#!/bin/bash

function migrate_statuses() {
    local year=$1
    local project_dir=$2

    if [ -z "${year}" ];
    then
        echo 'Please provide a year as first argument.'
        return
    fi

    if [ -z "${project_dir}" ];
    then
        echo 'Please provide a project directory as second argument.'
        return
    fi

    for padding in `seq 0 2`;
    do
        for month in `seq 1 9`;
        do
            for day in `seq 1 9`;
                do "${project_dir}"/daily-press-review-golang \
                -aggregate-id=1 \
                -since-date=${year}-0$month-$padding$day \
                -in-parallel=true ;
            done;
        done;
        for month in `seq 1 2`;
        do
            for day in `seq 1 9`;
                do "${project_dir}"/daily-press-review-golang \
                -aggregate-id=1 \
                -since-date=${year}-1$month-$padding$day \
                -in-parallel=true ;
            done;
        done;
    done
    for padding in `seq 3 3`;
    do
        for month in `seq 1 9`;
            do
            for day in `seq 0 1`;
                do "${project_dir}"/daily-press-review-golang \
                    -aggregate-id=1 \
                    -since-date=${year}-0$month-$padding$day \
                    -in-parallel=true ;
                done;
        done;
        for month in `seq 1 2`;
            do
            for day in `seq 0 1`;
                do "${project_dir}"/daily-press-review-golang \
                -aggregate-id=1 \
                -since-date=${year}-1$month-$padding$day \
                -in-parallel=true ;
                done;
        done;
    done
}

alias migrate-status=migrate_statuses
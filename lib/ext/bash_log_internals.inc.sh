#!/bin/bash

function test_dir() {
    log_debug "Testing directory '${1}'"
    if [ -d "${1}" ]
    then
        log_debug "'${1}' is a directory"
        return 0
    fi
    log_debug "'${1}' is not a directory"
    return 1
}

function test_file() {
    log_debug "Testing file '${1}'"
    if [ -f "${1}" ]
    then
        log_debug "'${1}' is a file"
        return 0
    fi
    log_debug "'${1}' is not a file"
    return 1
}

function test_exists() {
    log_debug "Testing exists '${1}'"
    if [ -e "${1}" ]
    then
        log_debug "'${1}' exists"
        return 0
    fi
    log_debug "'${1}' does not exist"
    return 1
}

function test_null() {
    log_debug "Testing null for '${1}'"
    if [ -z "${2}" ]
    then
        log_debug "'${1}' is null"
        return 0
    fi
    log_debug "'${1}' is not null"
    return 1
}

function test_not_empty() {
    log_debug "Testing not empty for '${1}'"
    if [ -n "${2}" ]
    then
        log_debug "'${1}' is not empty"
        return 0
    fi
    log_debug "'${1}' is empty"
    return 1
}

function exec_cmd() {
    log_debug "Running cmd '${*}'"
    exec 3>&2
    test_null "_FLAG_SILENT" "${_FLAG_SILENT}" && {
        { err="$( { "$@"; } 2>&1 1>&3 3>&- )"; } 3>&1 \
            || exit_error "${err}" 1;
        return 0
    }
    { err="$( { "$@"; } 2>&1 1>/dev/null 3>&- )"; } 3>&1 \
        || exit_error "${err}" 1
}

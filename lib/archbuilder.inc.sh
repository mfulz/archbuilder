#!/bin/bash

function exit_error() {
    log_error "${1}"
    exit ${2}
}

function check_mode() {
    log_debug "check_mode for val '${1}' called"
    if [ -z "${1}" ]
    then
        err="Mode not given"
        return 1
    fi

    case "$1" in
        "update")
            log_debug "Mode 'update' selected"
            return 0
            ;;
        "create")
            log_debug "Mode 'create' selected"
            return 0
            ;;
        "build")
            log_debug "Mode 'build' selected"
            return 0
            ;;
        *)
            err="Mode '${1}' invalid"
            return 1
            ;;
    esac
}

function check_log_level() {
    log_debug "check_log_level for val '${1}' called"
    if [ -z "${1}" ]
    then
        err="Log level cannot be empty"
        return 1
    fi

    case "$1" in
        "DEBUG" \
            | "INFO" \
            | "WARN" \
            | "SUCCESS" \
            | "ERROR")
            log_debug "Log level set to '${1}'"
            return 0
            ;;
        *)
            err="Log level '${1}' invalid"
            return 1
            ;;
    esac
}

function check_flag() {
    if [ -z "${2}" ]
    then
        log_debug "Flag '${1}' unset"
    else
        log_debug "Flag '${1}' set"
    fi
}

function set_env() {
    log_info "Checking environment and params"

    check_log_level "${LOG_LEVEL_STDOUT}" \
        || exit_error "Error setting log level for stdout: '${err}'"
    check_log_level "${LOG_LEVEL_LOG}" \
        || exit_error "Error setting log level for log file: '${err}'"

    log_debug "Verifying mode '${_OPT_MODE}'"
    check_mode "${_OPT_MODE}" \
        || exit_error "${err}" 1

    check_flag "KEEP" "${_FLAG_KEEP}"
    check_flag "SILENT" "${_FLAG_SILENT}"

    test_exists "${ARCHBUILDER_BASE_DIR}" || _ACT_CREATE_BASE_DIR=1
    check_flag "_ACT_CREATE_BASE_DIR" "${_ACT_CREATE_BASE_DIR}"

    test_exists "${ARCHBUILDER_CACHE_REPO}" || _ACT_CREATE_CACHE_REPO_PATH=1
    check_flag "_ACT_CREATE_CACHE_REPO_PATH" "${_ACT_CREATE_CACHE_REPO_PATH}"

    test_exists "${ARCHBUILDER_LOG_PATH}" || _ACT_CREATE_LOG_PATH=1
    check_flag "_ACT_CREATE_LOG_PATH" "${_ACT_CREATE_LOG_PATH}"

    buildah_exists "${ARCHBUILDER_IMAGE_NAME}" || _ACT_CREATE_IMAGE=1
    check_flag "_ACT_CREATE_IMAGE" "${_ACT_CREATE_IMAGE}"

    test_null "ARCHBUILDER_IMAGE_NAME" "${ARCHBUILDER_IMAGE_NAME}" \
        && exit_error "Image name cannot be empty" 1

    return 0
}

function init_env() {
    log_info "Initializing environment"
    
    test_null "_ACT_CREATE_BASE_DIR" "${_ACT_CREATE_BASE_DIR}" \
        || log_info "Creating directory '${ARCHBUILDER_BASE_DIR}'"; {
            err="$(mkdir -p "${ARCHBUILDER_BASE_DIR}" 1>/dev/null)" \
                || exit_error "Failed to create directory '${ARCHBUILDER_BASE_DIR}': '${err}'" 1
        }
    test_dir "${ARCHBUILDER_BASE_DIR}" \
        || exit_error "Not a directory '${ARCHBUILDER_BASE_DIR}'" 1

    test_null "_ACT_CREATE_CACHE_REPO_PATH" "${_ACT_CREATE_CACHE_REPO_PATH}" \
        || log_info "Creating directory '${ARCHBUILDER_CACHE_REPO}'"; {
            err="$(mkdir -p "${ARCHBUILDER_CACHE_REPO}" 1>/dev/null)" \
                || exit_error "Failed to create directory '${ARCHBUILDER_CACHE_REPO}': '${err}'" 1
        }
    test_dir "${ARCHBUILDER_CACHE_REPO}" \
        || exit_error "Not a directory '${ARCHBUILDER_CACHE_REPO}'" 1

    test_null "_ACT_CREATE_LOG_PATH" "${_ACT_CREATE_LOG_PATH}" \
        || log_info "Creating directory '${ARCHBUILDER_LOG_PATH}'"; {
            err="$(mkdir -p "${ARCHBUILDER_LOG_PATH}" 1>/dev/null)" \
                || exit_error "Failed to create directory '${ARCHBUILDER_LOG_PATH}': '${err}'" 1
        }
    test_dir "${ARCHBUILDER_LOG_PATH}" \
        || exit_error "Not a directory '${ARCHBUILDER_LOG_PATH}'" 1

    test_null "ARCHBUILDER_LOG_TO_FILE" "${ARCHBUILDER_LOG_TO_FILE}" \
        || {
            LOG_PATH="${ARCHBUILDER_LOG_PATH}/$(date +"%F-%H_%M_%S").log"
            log_info "Logfile: '${LOG_PATH}'"
        }

    log_info "Environment ready"
}

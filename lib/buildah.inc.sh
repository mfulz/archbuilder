#!/bin/bash

_BUILDAH_CONT=""

_BUILDAH_BASE_IMAGE="archlinux"
_BUILDAH_BASE_PATH="/home/archbuilder"
_BUILDAH_MKPKG_PATH="${_BUILDAH_BASE_PATH}/mkpgs"
_BUILDAH_PKGDEST_PATH="${_BUILDAH_BASE_PATH}/pkgdest"
_BUILDAH_CACHE_REPO_NAME="archbuilder_cache_repo"
_BUILDAH_CACHE_REPO_PATH="${_BUILDAH_BASE_PATH}/crepo"
_BUILDAH_CACHE_REPO="${_BUILDAH_CACHE_REPO_PATH}/${_BUILDAH_CACHE_REPO_NAME}.db.tar.gz"
_BUILDAH_MOUNTS=()

_BUILDAH_PARAMS=""
_BUILDAH_MAKEPKG_ENV=""
_BUILDAH_MAKEPKG_FLAGS=" --noconfirm" # always noconfirm to avoid hanging

function buildah_exists() {
    log_debug "Checking if buildah image '${1}' exists"

    if buildah inspect "${1}" > /dev/null 2>&1
    then
        log_debug "Buildah image '${1}' exists"
        return 0
    fi
    
    log_debug "Buildah image '${1}' does not exist"
    return 1
}

function buildah_prepare_params() {
    _BUILDAH_PARAMS="${_BUILDAH_PARAMS} -v ${ARCHBUILDER_CACHE_REPO}:${_BUILDAH_CACHE_REPO_PATH}:rw,U"

    # adding working directory to container
    _BUILDAH_PARAMS="${_BUILDAH_PARAMS} -v $(pwd):${_BUILDAH_MKPKG_PATH}:rw,U"

    log_info "Preparing makepkg environment"
    test_null "PKGDEST" "${PKGDEST}" || {
        _BUILDAH_PARAMS="${_BUILDAH_PARAMS} -v ${PKGDEST}:${_BUILDAH_PKGDEST_PATH}:rw,U"
        _BUILDAH_MAKEPKG_ENV="${_BUILDAH_MAKEPKG_ENV} PKGDEST=${_BUILDAH_PKGDEST_PATH}"
    }

    log_debug "Final _BUILDAH_PARAMS '${_BUILDAH_PARAMS}'"
}

function buildah_exit() {
    # fix permissions in any case
    log_info "Cleaning up buildah stuff"
    test_null "_BUILDAH_CONT" "${_BUILDAH_CONT}" || {
        exec_cmd buildah run ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" bash -c "exit 0"

        test_null "_FLAG_KEEP" "${_FLAG_KEEP}" && {
            log_info "Deleting working container '${_BUILDAH_CONT}'"
            exec_cmd buildah rm "${_BUILDAH_CONT}"
        }
        unset _BUILDAH_CONT
    }
}

function buildah_create() {
    # checking if base image is existing
    buildah_exists "${_BUILDAH_BASE_IMAGE}" || {
        log_info "Trying to fetch base image '${_BUILDAH_BASE_IMAGE}'"
        exec_cmd buildah pull "${_BUILDAH_BASE_IMAGE}"
    }

    test_null "_ACT_CREATE_IMAGE" "${_ACT_CREATE_IMAGE}" \
        && return 0

    log_info "Creating working container '${ARCHBUILDER_IMAGE_NAME}' from '${_BUILDAH_BASE_IMAGE}'"
    _BUILDAH_CONT=$(buildah from --name "${ARCHBUILDER_IMAGE_NAME}" "${_BUILDAH_BASE_IMAGE}")

    log_info "Updating working container '${ARCHBUILDER_IMAGE_NAME}'"
    exec_cmd buildah run "${_BUILDAH_CONT}" pacman --noconfirm -Syu
    
    log_info "Installing devel packages"
    exec_cmd buildah run "${_BUILDAH_CONT}" pacman --noconfirm -S base-devel sudo vim git

    log_info "Creating user '${_OPT_CON_BUILD_USER}'"
    exec_cmd buildah run "${_BUILDAH_CONT}" useradd -m -s /bin/bash -U -u 1000 "${_OPT_CON_BUILD_USER}"

    log_info "Setting up sudo for user '${_OPT_CON_BUILD_USER}'"
    exec_cmd buildah run "${_BUILDAH_CONT}" bash -c "echo '${_OPT_CON_BUILD_USER} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/${_OPT_CON_BUILD_USER}"

    log_info "Creating container folder '${_BUILDAH_DEP_PATH}'"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" "${_BUILDAH_CONT}" mkdir "${_BUILDAH_DEP_PATH}"

    log_info "Creating container folder '${_BUILDAH_MKPKG_PATH}'"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" "${_BUILDAH_CONT}" mkdir "${_BUILDAH_MKPKG_PATH}"

    log_info "Creating container folder '${_BUILDAH_PKGDEST_PATH}'"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" "${_BUILDAH_CONT}" mkdir "${_BUILDAH_PKGDEST_PATH}"

    log_info "Creating container folder '${_BUILDAH_CACHE_REPO_PATH}'"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" "${_BUILDAH_CONT}" mkdir "${_BUILDAH_CACHE_REPO_PATH}"

    log_info "Adding repository '${_BUILDAH_CACHE_REPO} 'to container"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" repo-add "${_BUILDAH_CACHE_REPO}"
    exec_cmd buildah run "${_BUILDAH_CONT}" bash -c "echo -e \"\n\" >> /etc/pacman.conf"
    exec_cmd buildah run "${_BUILDAH_CONT}" bash -c "echo -e \"[${_BUILDAH_CACHE_REPO_NAME}]\" >> /etc/pacman.conf"
    exec_cmd buildah run "${_BUILDAH_CONT}" bash -c "echo -e \"SigLevel = Optional TrustAll\" >> /etc/pacman.conf"
    exec_cmd buildah run "${_BUILDAH_CONT}" bash -c "echo -e \"Server = file://${_BUILDAH_CACHE_REPO_PATH}\" >> /etc/pacman.conf"

    log_info "Copying host makepkg.conf to container"
    exec_cmd buildah copy --chown root:root "${_BUILDAH_CONT}" "/etc/makepkg.conf" "/etc/makepkg.conf"

    log_info "Finalizing image '${ARCHBUILDER_IMAGE_NAME}'"
    exec_cmd buildah commit "${_BUILDAH_CONT}" "${ARCHBUILDER_IMAGE_NAME}"

    buildah_exit
}

function buildah_update() {
    buildah_exists "${ARCHBUILDER_IMAGE_NAME}" \
        || exit_error "Build image '${ARCHBUILDER_IMAGE_NAME}' does not exist" 1

    log_info "Creating working container '${ARCHBUILDER_IMAGE_NAME}' from '${ARCHBUILDER_IMAGE_NAME}'"
    _BUILDAH_CONT=$(buildah from --name "${ARCHBUILDER_IMAGE_NAME}" "${ARCHBUILDER_IMAGE_NAME}")

    log_info "Copying host makepkg.conf to container"
    exec_cmd buildah copy --chown root:root "${_BUILDAH_CONT}" "/etc/makepkg.conf" "/etc/makepkg.conf"

    log_info "Updating container system"
    exec_cmd buildah run --user ${_OPT_CON_BUILD_USER} ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" sudo pacman --noconfirm -Syu

    log_info "Finalizing image '${ARCHBUILDER_IMAGE_NAME}'"
    buildah commit "${_BUILDAH_CONT}" "${ARCHBUILDER_IMAGE_NAME}"

    buildah_exit
}

function buildah_prepare_build() {
    buildah_exists "${ARCHBUILDER_IMAGE_NAME}" \
        || exit_error "Build image '${ARCHBUILDER_IMAGE_NAME}' does not exist" 1

    log_info "Creating working container '${ARCHBUILDER_IMAGE_NAME}' from '${ARCHBUILDER_IMAGE_NAME}'"
    _BUILDAH_CONT=$(buildah from --name "${ARCHBUILDER_IMAGE_NAME}" "${ARCHBUILDER_IMAGE_NAME}")

    log_info "Copying host makepkg.conf to container"
    exec_cmd buildah copy --chown root:root "${_BUILDAH_CONT}" "/etc/makepkg.conf" "/etc/makepkg.conf"

    log_info "Updating container system"
    exec_cmd buildah run --user ${_OPT_CON_BUILD_USER} ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" sudo pacman --noconfirm -Syu

    for k in "${_OPT_KEYS[@]}"
    do
        exec_cmd buildah run --user ${_OPT_CON_BUILD_USER} ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" gpg --receive-keys "${k}"
    done
}

function buildah_build() {
    buildah_prepare_build

    arrExt=$(grep PKGEXT /etc/makepkg.conf)
    arrExt=(${arrExt//=/ })
    ext=$(echo "${arrExt[1]}" | cut -d "'" -f 2)

    log_debug "Running makepkg"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" \
        bash -c "cd ${_BUILDAH_MKPKG_PATH} && ${_BUILDAH_MAKEPKG_ENV} makepkg ${_BUILDAH_MAKEPKG_FLAGS} ${_OPT_CON_COPTIONS}"

    log_debug "Copying to cache repo"
    test_null "PKGDEST" "${PKGDEST}" && {
        exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" bash -c "cp ${_BUILDAH_MKPKG_PATH}/*${ext} ${_BUILDAH_CACHE_REPO_PATH}"
    } || {
        exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" bash -c "cp ${_BUILDAH_PKGDEST_PATH}/*${ext} ${_BUILDAH_CACHE_REPO_PATH}"
    }

    log_debug "Updating cache repo"
    exec_cmd buildah run --user "${_OPT_CON_BUILD_USER}" ${_BUILDAH_PARAMS} "${_BUILDAH_CONT}" bash -c "repo-add -n ${_BUILDAH_CACHE_REPO} ${_BUILDAH_CACHE_REPO_PATH}/*${ext}"

    buildah_exit
}



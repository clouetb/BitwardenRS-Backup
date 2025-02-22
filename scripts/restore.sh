#!/bin/bash

. /app/includes.sh

RESTORE_FILE_DB=""
RESTORE_FILE_CONFIG=""
RESTORE_FILE_ATTACHMENTS=""
RESTORE_FILE_ZIP=""
RESTORE_FILE_DIR="${RESTORE_DIR}"
ZIP_PASSWORD=""

function clear_extract_dir() {
    rm -rf "${RESTORE_EXTRACT_DIR}"
}

function restore_zip() {
    color blue "restore bitwarden_rs backup zip file"

    local FIND_FILE_DB
    local FIND_FILE_CONFIG
    local FIND_FILE_ATTACHMENTS

    if [[ -n "${ZIP_PASSWORD}" ]]; then
        7z e -aoa -p"${ZIP_PASSWORD}" -o"${RESTORE_EXTRACT_DIR}" "${RESTORE_FILE_ZIP}"
    else
        7z e -aoa -o"${RESTORE_EXTRACT_DIR}" "${RESTORE_FILE_ZIP}"
    fi

    if [[ $? == 0 ]]; then
        color green "extract bitwarden_rs backup zip file successful"
    else
        color red "extract bitwarden_rs backup zip file failed"
        exit 1
    fi

    # get restore db file
    FIND_FILE_DB="$( basename "$(ls ${RESTORE_EXTRACT_DIR}/db.*.sqlite3 2>/dev/null)" )"
    RESTORE_FILE_DB="${FIND_FILE_DB:-}"

    # get restore config file
    FIND_FILE_CONFIG="$( basename "$(ls ${RESTORE_EXTRACT_DIR}/config.*.json 2>/dev/null)" )"
    RESTORE_FILE_CONFIG="${FIND_FILE_CONFIG:-}"

    # get restore attachments file
    FIND_FILE_ATTACHMENTS="$( basename "$(ls ${RESTORE_EXTRACT_DIR}/attachments.*.tar 2>/dev/null)" )"
    RESTORE_FILE_ATTACHMENTS="${FIND_FILE_ATTACHMENTS:-}"

    RESTORE_FILE_ZIP=""
    RESTORE_FILE_DIR="${RESTORE_EXTRACT_DIR}"
    restore_file
}

function restore_db() {
    color blue "restore bitwarden_rs sqlite database"

    cp -f "${RESTORE_FILE_DB}" "${DATA_DB}"

    if [[ $? == 0 ]]; then
        color green "restore bitwarden_rs sqlite database successful"
    else
        color red "restore bitwarden_rs sqlite database failed"
    fi
}

function restore_config() {
    color blue "restore bitwarden_rs config"

    cp -f "${RESTORE_FILE_CONFIG}" "${DATA_CONFIG}"

    if [[ $? == 0 ]]; then
        color green "restore bitwarden_rs config successful"
    else
        color red "restore bitwarden_rs config failed"
    fi
}

function restore_attachments() {
    color blue "restore bitwarden_rs attachments"

    # When customizing the attachments folder, the root directory of the tar file
    # is the directory name at the time of packing
    local RESTORE_FILE_ATTACHMENTS_DIRNAME=$(tar -tf "${RESTORE_FILE_ATTACHMENTS}" | head -n 1 | xargs basename)
    local DATA_ATTACHMENTS_EXTRACT="${DATA_ATTACHMENTS}.extract"

    rm -rf "${DATA_ATTACHMENTS}" "${DATA_ATTACHMENTS_EXTRACT}"
    mkdir "${DATA_ATTACHMENTS_EXTRACT}"
    tar -x -C "${DATA_ATTACHMENTS_EXTRACT}" -f "${RESTORE_FILE_ATTACHMENTS}"
    mv "${DATA_ATTACHMENTS_EXTRACT}/${RESTORE_FILE_ATTACHMENTS_DIRNAME}" "${DATA_ATTACHMENTS}"
    rm -rf "${DATA_ATTACHMENTS_EXTRACT}"

    if [[ $? == 0 ]]; then
        color green "restore bitwarden_rs attachments successful"
    else
        color red "restore bitwarden_rs attachments failed"
    fi
}

function check_restore_file_exist() {
    if [[ ! -f "${RESTORE_FILE_DIR}/$1" ]]; then
        color red "$2: cannot access $1: No such file"
        exit 1
    fi
}

function restore_file() {
    if [[ -n "${RESTORE_FILE_ZIP}" ]]; then
        check_restore_file_exist "${RESTORE_FILE_ZIP}" "--zip-file"

        RESTORE_FILE_ZIP="${RESTORE_FILE_DIR}/${RESTORE_FILE_ZIP}"

        clear_extract_dir
        restore_zip
        clear_extract_dir
    else
        if [[ -n "${RESTORE_FILE_DB}" ]]; then
            check_restore_file_exist "${RESTORE_FILE_DB}" "--db-file"

            RESTORE_FILE_DB="${RESTORE_FILE_DIR}/${RESTORE_FILE_DB}"
        fi

        if [[ -n "${RESTORE_FILE_CONFIG}" ]]; then
            check_restore_file_exist "${RESTORE_FILE_CONFIG}" "--config-file"

            RESTORE_FILE_CONFIG="${RESTORE_FILE_DIR}/${RESTORE_FILE_CONFIG}"
        fi

        if [[ -n "${RESTORE_FILE_ATTACHMENTS}" ]]; then
            check_restore_file_exist "${RESTORE_FILE_ATTACHMENTS}" "--attachments-file"

            RESTORE_FILE_ATTACHMENTS="${RESTORE_FILE_DIR}/${RESTORE_FILE_ATTACHMENTS}"
        fi

        if [[ -n "${RESTORE_FILE_DB}" ]]; then
            restore_db
        fi
        if [[ -n "${RESTORE_FILE_CONFIG}" ]]; then
            restore_config
        fi
        if [[ -n "${RESTORE_FILE_ATTACHMENTS}" ]]; then
            restore_attachments
        fi
    fi
}

function check_empty_input() {
    if [[ -z "${RESTORE_FILE_ZIP}${RESTORE_FILE_DB}${RESTORE_FILE_CONFIG}${RESTORE_FILE_ATTACHMENTS}" ]]; then
        color yellow "Empty input"
        color none ""
        color none "Find out more at https://github.com/ttionya/BitwardenRS-Backup#restore"
        exit 0
    fi
}

function check_data_dir_exist() {
    if [[ ! -d "${DATA_DIR}" ]]; then
        color red "Bitwarden data directory not found"
        exit 1
    fi
}

function restore() {
    local READ_RESTORE_CONTINUE

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--password)
                shift
                ZIP_PASSWORD="$1"
                shift
                ;;
            --zip-file)
                shift
                RESTORE_FILE_ZIP="$(basename "$1")"
                shift
                ;;
            --db-file)
                shift
                RESTORE_FILE_DB="$(basename "$1")"
                shift
                ;;
            --config-file)
                shift
                RESTORE_FILE_CONFIG="$(basename "$1")"
                shift
                ;;
            --attachments-file)
                shift
                RESTORE_FILE_ATTACHMENTS="$(basename "$1")"
                shift
                ;;
            *)
                color red "Illegal input"
                exit 1
                ;;
        esac
    done

    init_env_dir
    check_empty_input
    check_data_dir_exist

    color yellow "Restore will overwrite the existing files, continue? (y/N)"
    read -p "(Default: n): " READ_RESTORE_CONTINUE
    if [[ $(echo "${READ_RESTORE_CONTINUE:-n}" | tr [a-z] [A-Z]) == "Y" ]]; then
        restore_file
    fi
}

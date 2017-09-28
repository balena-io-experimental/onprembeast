#!/bin/bash

NOREBOOT=no
STAGING=no
LOG=yes
SCRIPTNAME=hostapps-update.sh

set -o errexit
set -o pipefail

# This will set VERSION, SLUG, and VARIANT_ID
. /etc/os-release

# Don't run anything before this source as it sets PATH here
source /etc/profile

# Log timer
STARTTIME=$(date +%s)

###
# Helper functions
###

# Dashboard progress helper
function progress {
    percentage=$1
    message=$2
    resin-device-progress --percentage "${percentage}" --state "${message}" > /dev/null || true
}

function help {
    cat << EOF
Helper to run hostOS updates on resinOS 2.x devices

Options:
  -h, --help
        Display this help and exit.

  --hostos-version <image>
        Run the updater for this specific hostapps docker image.

EOF
}

# Log function helper
function log {
    # Address log levels
    case $1 in
        ERROR)
            loglevel=ERROR
            shift
            ;;
        WARN)
            loglevel=WARNING
            shift
            ;;
        *)
            loglevel=LOG
            ;;
    esac
    endtime=$(date +%s)
    if [ "z$LOG" == "zyes" ] && [ -n "$LOGFILE" ]; then
        printf "[%09d%s%s\n" "$((endtime - starttime))" "][$loglevel]" "$1" | tee -a "$LOGFILE"
    else
        printf "[%09d%s%s\n" "$((endtime - starttime))" "][$loglevel]" "$1"
    fi
    if [ "$loglevel" == "ERROR" ]; then
        progress 100 "ResinOS: Update failed."
        exit 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in
        -h|--help)
            help
            exit 0
            ;;
        --hostos-version)
            if [ -z "$2" ]; then
                log ERROR "\"$1\" argument needs a value."
            fi
            target_version=$2
            shift
            ;;
        *)
            log ERROR "Unrecognized option $1."
            ;;
    esac
    shift
done

if [ -z "$target_version" ]; then
    log ERROR "--hostos-version is required."
fi

progress 50 "ResinOS: running hostapps update..."

hostapp-update -i "${target_version}"

log "Rebooting into new OS in 5 seconds..."
progress 100 "ResinOS: update successful, rebooting..."
nohup bash -c " /bin/sleep 5 ; /sbin/reboot " > /dev/null 2>&1 &

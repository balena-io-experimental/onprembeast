#!/bin/bash

# Log function helper
function log {
    local COL
    local COLEND='\e[0m'
    local loglevel=LOG

    case $1 in
        ERROR)
            COL='\e[31m'
            loglevel=ERR
            shift
            ;;
        WARN)
            COL='\e[33m'
            loglevel=WRN
            shift
            ;;
        SUCCESS)
            COL='\e[32m'
            loglevel=LOG
            shift
            ;;
        *)
            COL=$COLEND
            loglevel=LOG
            ;;
    esac

    if [ "$NOCOLORS" == "yes" ]; then
        COLEND=''
        COL=''
    fi

    ENDTIME=$(date +%s)
    printf "${COL}[%09d%s%s${COLEND}\n" "$((ENDTIME - STARTTIME))" "][$loglevel]" "$1"
    if [ "$loglevel" == "ERR" ]; then
        exit 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in
        -h|--hostos-version)
            if [ -z "$2" ]; then
                log ERROR "\"$1\" argument needs a value."
            fi
            target_version=$2
            shift
            ;;
        -a|--application)
            if [ -z "$2" ]; then
                log ERROR "\"$1\" argument needs a value."
            fi
            application=$2
            shift
            ;;
        *)
            log ERROR "Unrecognized option $1."
            ;;
    esac
    shift
done

#Check argument(s)
if [ -z "$target_version" ]; then
    log ERROR "Need to supply target version"
fi

if [ -z "$application" ]; then
    log ERROR "Need to supply application"
fi

device_array=($(resin devices --application "$application" | sed 1d | awk '{ print $2 }'))

HUP_ARGS=()
HUP_ARGS+=( "-m 30" )
HUP_ARGS+=( "--hostos-version $target_version" )

for uuid in "${device_array[@]}"; do
    echo "Found device: $uuid.local"
    HUP_ARGS+=( "-u $uuid.local" )
done
echo "args:"
echo "${HUP_ARGS[*]}"

echo "now calling hostapps-ssh-update.sh "

./hostapps-ssh-update.sh ${HUP_ARGS[*]}

#!/bin/bash

function help {
    cat << EOF
Helper script to trigger delta calculation between two images,
starting from a source image to a destination image.

Options:
    -h, --help
        Display this help and exit.

    -s, --source SRC
        The docker image is the base of the delta calculation

    -d, --dest DEST
        The docker image that is the destination of the delta calculation, which is
        the docker image that should result in the delta applied on top of source.

    -t, --tag TAG
        Tag the resulting image like this, if delta generation is successful.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in
        -h|--help)
            help
            exit 0
            ;;
        -s|--source)
            if [ -z "$2" ]; then
                echo "\"$1\" argument needs a value."
            fi
            SRC=$2
            shift
            ;;
        -d|--dest)
            if [ -z "$2" ]; then
                echo "\"$1\" argument needs a value."
            fi
            DEST=$2
            shift
            ;;
        -t|--tag)
            if [ -z "$2" ]; then
                echo "\"$1\" argument needs a value."
            fi
            TAG=$2
            shift
            ;;
        *)
            echo "Unrecognized option $1."
            exit 1
            ;;
    esac
    shift
done

if [ -z "${SRC+x}" ]; then
    echo -e '\033[1mError, source image is required!\033[0m'
    echo
    help
    exit 1
fi
if [ -z "${DEST+x}" ]; then
    echo -e '\033[1mError, destination image is required!\033[0m'
    echo
    help
    exit 1
fi

resp=$(curl -s -X POST -d "src=${SRC}&dest=${DEST}" http://localhost:2375/deltas/create)
echo "$resp"
# returns code 201 if successful and the delta's SHA256 value in response body

if [ -n "$TAG" ]; then
    if [[ $resp =~ ^.*message.*$ ]]; then
        echo "Can't tag since there seem to be an error generating the delta..."
    else
        # shellcheck disable=SC2001
        id=$(echo "$resp" | sed 's/.*sha256:\([a-fA-F0-9]*\).*/\1/')
        docker tag "${id}" "${TAG}"
    fi
fi

#! /bin/bash

set -e


NAME=$(basename `pwd`)
# Local machine build
build() {
    IMAGE_NAME=$(basename $(dirname $(pwd)))/$(basename $(pwd)) 
    DOCKER_TAG=latest
    source ./hooks/build
}

run() {
   echo "Not supported"
}


case $1 in
    "build")
        build
    ;;
    "install")
        run
    ;;

    "build-run")
        build
        install
    ;;
    *)
        echo "Specify 'build', 'run' or 'build-run'"
    ;;
esac




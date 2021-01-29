#! /bin/bash

set -e


NAME=$(basename `pwd`)
IMAGE_NAME=$(basename $(dirname $(pwd)))/$(basename $(pwd))
DOCKER_TAG=latest

# Local machine build
build() {
    source ./hooks/build
}

run() {
   echo "Not supported"
}

push() {
    DEV_IMAGE=${IMAGE_NAME}:development
    echo "Creating development tag from latest"
    docker tag ${IMAGE_NAME}:${DOCKER_TAG} ${DEV_IMAGE}
    echo "Pushing development tag" 
    docker push ${DEV_IMAGE}
}

case $1 in
    "build")
        build
    ;;
    "install")
        run
    ;;
    "build-install")
        build
        install
    ;;
    "build-push")
        build
        push
    ;;
    *)
        echo "Specify 'build', or 'build-install'"
    ;;
esac




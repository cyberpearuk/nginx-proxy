#! /bin/bash

set -e

NAMESPACE=$(basename $(dirname $(pwd)))
NAME=$(basename `pwd`)
DOCKER_TAG=development

IMAGE_NAME=${NAMESPACE}/${NAME}:${DOCKER_TAG}

# Local machine build
build() {
    docker build -t $IMAGE_NAME --build-arg VERSION=$DOCKER_TAG --target=nginx-base .
}

run() {
   echo "Not supported"
}

push() {
    echo "Pushing tag ${IMAGE_NAME}" 
    docker push ${IMAGE_NAME}
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




#! /bin/bash

set -e

NAMESPACE=$(basename $(dirname $(pwd)))
NAME=$(basename `pwd`)
DOCKER_TAG=development

IMAGE_NAME=${NAMESPACE}/${NAME}

# Local machine build
build() {
    # Build image with everything
    docker build -t $IMAGE_NAME:docker-gen  --build-arg VERSION=$DOCKER_TAG --target=production .
    # Build image with just Nginx and config
    docker build -t $IMAGE_NAME:development --build-arg VERSION=$DOCKER_TAG --target=nginx-base .
}

run() {
   echo "Not supported"
}

push() {
    # Only pushes development tag
    echo "Pushing tag ${IMAGE_NAME}":development 
    docker push ${IMAGE_NAME}:development 
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




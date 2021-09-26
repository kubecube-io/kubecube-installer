#!/bin/bash

BASE_PATH=.
KUBERNETES_VERSION=1.20.9

function offline_pkg_download() {

}

function offline_image_download() {
    for image in $(cat ${BASE_PATH}/images/v${KUBERNETES_VERSION}/images.list)
    do
      docker pull ${image}
    done

    images=""
    for image in $(cat ${BASE_PATH}/images/v${KUBERNETES_VERSION}/images.list)
    do
      images="$images $image"
    done

    docker save -o kubecube.tar ${images}
}

function main() {
  offline_image_download
}

main
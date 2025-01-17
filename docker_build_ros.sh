#!/bin/bash
# Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# reference
# https://gitlab.com/nvidia/container-images/samples/-/blob/main/deployments/container/Makefile
# https://gitlab.com/nvidia/container-images/samples/-/blob/main/deployments/container/Dockerfile.ubuntu
# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/cuda/tags

bold=`tput bold`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
reset=`tput sgr0`

docker_repo_name=novelte/jetson_dev
BASE_DIST=ubuntu20.04
L4T=35.3
CUDA_VERSION=11.8.0
OPENCV_VERSION=4.6.0
BUILD_BASE=devel
ROS_DISTRO=humble

usage()
{
    if [ "$1" != "" ]; then
        echo "${red}$1${reset}" >&2
    fi

    local name=$(basename ${0})
    echo "$name isaac_ros_base for different architectures." >&2
    echo "${bold}Commands:${reset}" >&2
    echo "  $name help                          This help" >&2
    echo "  $name opencv [OPTIONS ...]          Build opencv image" >&2
    echo "  $name devel [OPTIONS ...]           Build devel image" >&2
    echo "  $name runtime [OPTIONS ...]         Build runtime image" >&2
    echo "  $name ros [BASE] [OPTIONS ...]      Build ROS2 ros image" >&2
    echo "  $name gems [OPTIONS ...]            Build all Isaac ROS packages in a image" >&2
    echo
    echo "${bold}BASE:${reset}" >&2
    echo " core                                 Ros core packages" >&2
    echo " base                                 Ros base packages" >&2
    echo "${bold}OPTIONS:${reset}" >&2
    echo " --buildx                             Use docker buildx" >&2
    echo " --push                               Push docker image" >&2
    echo " --extract                            Extract OpenCV tar ball from docker" >&2
    echo " --ci                                 Run build in CI (without cash and pull a latest base image)" >&2
    echo " --base [NAME]                        Build from base image. Default: ${bold}$BUILD_BASE${reset}" >&2
    echo " --multiarch                          Build in multiarch (ARM64 and AMD64)" >&2
    echo " --l4t                                Build with L4T Default: L4T=$L4T" >&2
    echo " --arm64                              Build for arm64 architecture" >&2
    echo " --amd64                              Build for x86_64 architecture" >&2
    echo " --distro                             Build ROS Distro Default: ROS_DISTRO=$ROS_DISTRO" >&2
    echo " --manifest                           Build and push a manifest to merge two architecture" >&2
}

message_start()
{
    local PUSH=$1
    local CI=$2
    local TAG=$3
    # Push message
    if $CI ; then
        echo " - ${bold}CI${reset} setup"
    fi
    if $PUSH ; then
        echo " - ${bold}BUILD & PUSH${reset} $docker_repo_name:$TAG"
    else
        echo " - ${bold}BUILD${reset} $docker_repo_name:$TAG"
    fi
}

main()
{
    local MULTIARCH=false
    local CI_BUILD=false
    local PUSH=false
    local BUILDX=""
    local EXTRACT=false
    local MANIFEST=false
    # Autoselect mode
    local ARCH=$(uname -i)
    if [ "$ARCH" == "x86_64" ] ; then
        ARCH="amd64"
    else
        ARCH="arm64"
    fi

    # Check if run in sudo
    if [[ `id -u` -eq 0 ]] ; then 
        echo "${red}Please don't run as root${reset}" >&2
        exit 1
    fi
    local option=$1
    if [ -z "$option" ] ; then
        usage
        exit 0
    fi

    local ROS_PKG=""
    if [ $option = "ros" ] ; then
        case "$2" in
            core)
                ROS_PKG=core
                shift 1
                ;;
            base)
                ROS_PKG=base
                shift 1
                ;;
            *)
                usage "[ERROR] Unknown option: $2" >&2
                exit 1
                ;;
        esac
    fi

    # Load all arguments except the first one
    while [ -n "$2" ]; do
        case "$2" in
            --buildx) # Load help
                BUILDX=buildx
                ;;
            --ci)
                CI_BUILD=true
                ;;
            --arm64)
                ARCH="arm64"
                ;;
            --amd64)
                ARCH="amd64"
                ;;
            --l4t)
                L4T=$3
                shift 1
                ;;
            --base)
                BUILD_BASE=$3
                shift 1
                ;;
            --multiarch)
                MULTIARCH=true
                ;;
            --push)
                PUSH=true
                ;;
            --extract)
                EXTRACT=true
                ;;
            --distro)
                ROS_DISTRO="humble"
                ;;
            --manifest)
                MANIFEST=true
                ;;
            *)
                usage "[ERROR] Unknown option: $2" >&2
                exit 1
                ;;
        esac
            shift 1
    done

    # Check if Desktop has GPU
    if [ "$ARCH" == "amd64" ] ; then
        if type nvidia-smi &>/dev/null; then
            local GPU_ATTACHED=(`nvidia-smi -a | grep "Attached GPUs"`)
            if [ ! -z $GPU_ATTACHED ]; then
                echo "${green}GPU $GPU_ATTACHED${reset}"
            else
                echo "${red}GPU not attached. Check if driver are installed.${reset}"
                exit 1
            fi
        fi
    fi

    # Build options for docker
    local multiarch_option=""
    local push_value=""
    local CI_OPTIONS=""
    if [ ! -z $BUILDX ] ; then
        if $MULTIARCH ; then
            multiarch_option="--platform linux/arm64,linux/amd64"
        elif [ "$ARCH" == "arm64" ] ; then
            multiarch_option="--platform linux/arm64"
        elif [ "$ARCH" == "amd64" ] ; then
            multiarch_option="--platform linux/amd64"
        fi
        # Buildx push option
        push_value="--push"
    else
        if $PUSH ; then
            push_value="--push"
        fi

        if $CI_BUILD ; then
            # Set no-cache and pull before build
            # https://newbedev.com/what-s-the-purpose-of-docker-build-pull
            CI_OPTIONS="--no-cache --pull"
        fi
    fi

    if ((${L4T} > 35.3)) ; then
        echo "${red} L4t version higher than 35.3 is not supported"
        exit 1
    fi

    if ((${L4T//./ } < 35)) ; then
        BASE_DIST=ubuntu18.04
    fi

    # Build tag name
    local TAG="$option"

    # copy deb packages to jetson-containers/packages directory
    if [ $option = "opencv" ] && $EXTRACT ; then
        local architecture=$(uname -i)
        local OPENCV_PACKAGE="OpenCV-${OPENCV_VERSION}-${architecture}.tar.gz"

        docker run \
                --rm \
                --volume $PWD:/mount \
                $docker_repo_name:opencv-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} \
                cp /opt/opencv/build/$OPENCV_PACKAGE /mount
        
        if $? ; then
            echo "${red}Error to run the extraction${reset}"
            exit 1
        else
            echo "OpenCV package is at ${bold}$PWD/$OPENCV_PACKAGE${reset}"
        fi
        exit 0
    fi

    # Options
    if [ $option = "help" ] || [ $option = "-h" ]; then
        usage
        exit 0
    elif [ $option = "opencv" ] ; then
        #### OpenCV #############
        message_start $PUSH $CI_BUILD $TAG
        echo " - ${bold}OPENCV${reset} image"
        echo " - BASE_DIST=${green}$BASE_DIST${reset}"
        echo " - L4T=${green}$L4T${reset}"
        echo " - CUDA_VERSION=${green}$CUDA_VERSION${reset}"
        echo " - OPENCV_VERSION=${green}$OPENCV_VERSION${reset}"

        docker ${BUILDX} build \
            $push_value \
            $CI_OPTIONS \
            -t $docker_repo_name:opencv-${OPENCV_VERSION} \
            -t $docker_repo_name:opencv-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} \
            --build-arg BASE_DIST="$BASE_DIST" \
            --build-arg L4T="$L4T" \
            --build-arg CUDA_VERSION="$CUDA_VERSION" \
            --build-arg OPENCV_VERSION="$OPENCV_VERSION" \
            $multiarch_option \
            -f Dockerfile.opencv \
            . || { echo "${red}docker build failure!${reset}"; exit 1; }
        
        exit 0
    elif [ $option = "devel" ] || [ $option = "runtime" ] ; then

        # L4T 35.1
        local L4T_MINOR_VERSION=1.0
        local JETPACK=5.0.2
        local TAO_TENSORRT_VERSION=8.4
        local TRITON_VERSION=2.24.0
        local TRT_VERSION=8.5.2.2

        if [ $L4T == 35.2 ] ; then
            L4T_MINOR_VERSION=2.0
            JETPACK=5.1
            TRITON_VERSION=2.30.0
        elif [ $L4T == 35.3 ] ; then
            L4T_MINOR_VERSION=3.0
            JETPACK=5.1
            TRITON_VERSION=2.30.0
        fi

        
        if [ $L4T == 35.2 ] ; then
            JETPACK=5.1
        fi
        #### DEVEL #############
        message_start $PUSH $CI_BUILD $TAG
        echo " - ${bold}${option^^}${reset} image"
        echo " - BASE_DIST=${green}$BASE_DIST${reset}"
        echo " - L4T=${green}$L4T${reset}"
        echo " - L4T_MINOR_VERSION=${green}$L4T_MINOR_VERSION${reset}"
        echo " - JETPACK=${green}$JETPACK${reset}"
        echo " - CUDA_VERSION=${green}$CUDA_VERSION${reset}"
        echo " - OPENCV_VERSION=${green}$OPENCV_VERSION${reset}"
        echo " - TRITON_VERSION=${green}$TRITON_VERSION${reset}"
        echo " - TENSORRT_VERSION=${green}$TENSORRT_VERSION${reset}"

        docker ${BUILDX} build \
            $push_value \
            $CI_OPTIONS \
            -t $docker_repo_name:$TAG \
            -t $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} \
            --build-arg TAO_TENSORRT_VERSION="$TENSORRT_VERSION" \
            --build-arg TRT_VERSION="$TRT_VERSION" \
            --build-arg TRITON_VERSION="$TRITON_VERSION" \
            --build-arg BASE_DIST="$BASE_DIST" \
            --build-arg L4T="$L4T" \
            --build-arg L4T_MINOR_VERSION="$L4T_MINOR_VERSION" \
            --build-arg JETPACK="$JETPACK" \
            --build-arg CUDA_VERSION="$CUDA_VERSION" \
            --build-arg OPENCV_VERSION="$OPENCV_VERSION" \
            --build-arg DOCKER_REPO="$docker_repo_name" \
            $multiarch_option \
            -f Dockerfile.$option \
            . || { echo "${red}docker build failure!${reset}"; exit 1; }
        
        docker ${BUILDX} build \
            $push_value \
            $CI_OPTIONS \
            -t $docker_repo_name:$TAG \
            -t $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} \
            --build-arg BASE_IMAGE="$docker_repo_name:$TAG" \
            $multiarch_option \
            -f Dockerfile.realsense \
            . || { echo "${red}docker build failure!${reset}"; exit 1; }

        exit 0
    elif [ $option = "humble" ] ; then
        # Humble reference
        TAG="humble-$ROS_PKG-$BUILD_BASE"
        if [ $ROS_PKG = "core" ] ; then
            BASE_IMAGE=$docker_repo_name:$BUILD_BASE-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}
        elif [ $ROS_PKG = "base" ] ; then
            BASE_IMAGE=$docker_repo_name:humble-core-$BUILD_BASE-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}
        else
            echo "${red}Error base image!${reset}"
            exit 1
        fi
        #### HUMBLE #############
        message_start $PUSH $CI_BUILD $TAG
        echo " - ${bold}HUMBLE ${green}${ROS_PKG^^}${reset} image"
        echo " - BASE_IMAGE=${green}$BASE_IMAGE${reset}"
        echo " - L4T=${green}$L4T${reset}"

        docker ${BUILDX} build \
            $push_value \
            $CI_OPTIONS \
            -t $docker_repo_name:$TAG \
            -t $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} \
            --build-arg BASE_IMAGE="$BASE_IMAGE" \
            $multiarch_option \
            -f Dockerfile.humble.$ROS_PKG \
            . || { echo "${red}docker build failure!${reset}"; exit 1; }

        exit 0
    elif [ $option = "gems" ] ; then
        # tag and image reference
        TAG="gems-$BUILD_BASE"
        BASE_IMAGE=$docker_repo_name:humble-base-$BUILD_BASE-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}
        #### Message #############
        message_start $PUSH $CI_BUILD $TAG
        echo " - ${bold}${option^^}${reset} image"
        echo " - BASE_IMAGE=${green}$BASE_IMAGE${reset}"
        echo " - L4T=${green}$L4T${reset}"
        # Check to build a push a multiplatform manifest
        if $MANIFEST ; then
            echo "${green}Build and push manifest${reset}"
            # Pull images
            #docker pull $docker_repo_name:$TAG-arm64
            #docker pull $docker_repo_name:$TAG-amd64
            # Create a manifest
            docker manifest create $docker_repo_name:$TAG --amend $docker_repo_name:$TAG-arm64 --amend $docker_repo_name:$TAG-amd64
            docker manifest annotate --arch arm64 $docker_repo_name:$TAG $docker_repo_name:$TAG-arm64
            docker manifest annotate --arch amd64 $docker_repo_name:$TAG $docker_repo_name:$TAG-amd64
            # Create a manifest
            docker manifest create $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} --amend $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}-arm64 --amend $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}-amd64
            docker manifest annotate --arch arm64 $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}-arm64
            docker manifest annotate --arch amd64 $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T} $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}-amd64
            # Docker push manifest
            docker manifest push $docker_repo_name:$TAG
            docker manifest push $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}
            exit 0
        fi
        # Otherwise build the image
        # Temporary disabled buildx, need fix VPI for x86 architecture
        docker ${BUILDX} build \
            $CI_OPTIONS \
            -t $docker_repo_name:$TAG-$ARCH \
            -t $docker_repo_name:$TAG-${OPENCV_VERSION}-cuda${CUDA_VERSION}-${BASE_DIST}-L4T${L4T}-$ARCH \
            --cache-to=type=local,dest=/home/novelte/Docker-Cache,mode=max \
            --cache-from=type=local,src=/home/novelte/Docker-Cache \
            --build-arg BASE_IMAGE="$BASE_IMAGE" \
            $multiarch_option \
            -f Dockerfile.isaac \
            . || { echo "${red}docker build failure!${reset}"; exit 1; }

        exit 0
    fi

    

    usage "[ERROR] Unknown option: $option" >&2
    exit 1
}

main $@
exit 0
# EOF

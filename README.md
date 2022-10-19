# Isaac ROS Base - Multi architecture & CI based

[![Docker Pulls](https://img.shields.io/docker/pulls/rbonghi/isaac-ros-base)](https://hub.docker.com/r/rbonghi/isaac-ros-base) ![GitHub](https://img.shields.io/github/license/rbonghi/isaac_ros_base)

Multi architecture cross compilable Isaac ROS for x86 and NVIDIA Jetson with **Jetpack 5.0+**

# Requirements

To build these NVIDIA Docker you can choose one of these options:

1. **Desktop**
   * NVIDIA Graphic card
2. **NVIDIA Jetson**
   * Xavier or Orin series
   * Jetpack 5.0+

# Install

There are two ways to use this repository, build locally the isaac_ros_base images or use in CI, but you need to install a local runner on your desktop with NVIDIA graphic card

## Build locally

If you want to run locally use and follow the help:

> **Warning**: 
> You can use this script only on:
>  * x86 machines with NVIDIA graphic card
>  * NVIDIA Jetson Orin or Xavier series

```
./docker_build_ros.sh
```

## isaac_ros_runner

Follow README in [isaac_ros_runner](isaac_ros_runner) folder

## Images available

| Name                                | AMD64 | ARM64 |
|-------------------------------------|-------|-------|
| rbonghi/isaac_ros_base:devel        | [![Docker Image Size (tag)](https://img.shields.io/docker/image-size/rbonghi/isaac-ros-base/devel?arch=amd64)](https://hub.docker.com/r/rbonghi/isaac-ros-base) | [![Docker Image Size (tag)](https://img.shields.io/docker/image-size/rbonghi/isaac-ros-base/devel?arch=arm64)](https://hub.docker.com/r/rbonghi/isaac-ros-base) |
| rbonghi/isaac_ros_base:runtime      | Soon   | Soon   |
| rbonghi/isaac_ros_base:humble-devel | [![Docker Image Size (tag)](https://img.shields.io/docker/image-size/rbonghi/isaac-ros-base/humble-devel?arch=amd64)](https://hub.docker.com/r/rbonghi/isaac-ros-base) | [![Docker Image Size (tag)](https://img.shields.io/docker/image-size/rbonghi/isaac-ros-base/humble-devel?arch=arm64)](https://hub.docker.com/r/rbonghi/isaac-ros-base) |
| rbonghi/isaac_ros_base:humble       | Soon   | Soon   |

# Test build Isaac ROS

Example to build Isaac ROS packages multiplatform

```
cd example
docker build -t isaac-ros-base/packages:latest -f Dockerfile.isaac .
```
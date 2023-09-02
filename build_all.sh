#!/bin/bash
./docker_build_ros.sh opencv --multiarch --buildx --manifest --push
./docker_build_ros.sh devel --multiarch --buildx --manifest --push
./docker_build_ros.sh humble core --multiarch --buildx --manifest --push
./docker_build_ros.sh humble base --multiarch --buildx --manifest --push
# OpenVINO AI Sales Kit 
[![Stable release](https://img.shields.io/badge/version-2021.3-green.svg)](https://github.com/openvinotoolkit/openvino/releases/tag/2021.3)
[![Apache License Version 2.0](https://img.shields.io/badge/license-Apache_2.0-green.svg)](https://www.apache.org/licenses/LICENSE-2.0)

## Overview

This is container with OpenVINO™ Toolkit pre-installed.

## Running Containers

To pull this image, run:

```
$ docker pull sertek/openvino:2021.3_developer_models
```

To start the container, run:

```
$ docker run -it -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY -v ~/Downloads:/mnt --device /dev/dri:/dev/dri --device-cgroup-rule='c 189:* rmw' --device-cgroup-rule='c 180:* rmw' -v /dev:/dev --group-add=$(stat -c "%g" /dev/dri/render*) -v /var/tmp:/var/tmp --ipc=host --net=host -u root --rm sertek/openvino:2021.3_developer_models
```

You will be forwarded to the OpenVINO container environment and see following output, if successful:

```
[setupvars.sh] OpenVINO environment initialized
```

### To run Smart City Demo

Run below commands to get the streaming file:

```
$ wget -O ~/Downloads/NewVideo2.mp4 https://github.com/incluit/OpenVino-For-SmartCity/raw/master/data/NewVideo2.mp4
```

Run smart city demo with GPU:

```
$ docker run -it -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY -v ~/Downloads:/mnt --device /dev/dri:/dev/dri --device-cgroup-rule='c 189:* rmw' --device-cgroup-rule='c 180:* rmw' -v /dev:/dev --group-add=$(stat -c "%g" /dev/dri/render*) -v /var/tmp:/var/tmp --ipc=host --net=host -u root --rm sertek/openvino:2021.3_developer_models /home/openvino/smartcity_demo.sh
```

## License
This image is licensed under [Apache License Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
By contributing to the project, you agree to the license and copyright terms therein
and release your contribution under these terms.

## Resources:
* Originated: https://hackmd.io/@chungyeh/HklZFCA4d
* Base Docker Image: https://hub.docker.com/u/chungyehwangai
* [Intel® Distribution of OpenVINO™ toolkit Product Page](https://software.intel.com/content/www/us/en/develop/tools/openvino-toolkit.html)
* [Intel® Distribution of OpenVINO™ toolkit Release Notes](https://software.intel.com/en-us/articles/OpenVINO-RelNotes)

## Support
* [Sertek Inc., ](https://www.wpgholdings.com/yosung)
* The [`openvino`](https://stackoverflow.com/questions/tagged/openvino) tag on StackOverflow\*

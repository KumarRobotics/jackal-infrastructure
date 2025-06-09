#!/bin/bash

docker run --gpus=all --net=host --volume=$(pwd)/bags:/bags \
	-v "/dev:/dev" \
        --privileged \
        -e DISPLAY=$DISPLAY \
        -e QT_X11_NO_MITSHM=1 \
        -e XAUTHORITY=$XAUTH \
	-v "./mocha_config/radio_configs.yaml:/home/dcist/dcist_ws/src/MOCHA/mocha_core/config/radio_configs.yaml" \
	-v "./mocha_config/robot_configs.yaml:/home/dcist/dcist_ws/src/MOCHA/mocha_core/config/robot_configs.yaml" \
	-v "./mocha_config/topic_configs.yaml:/home/dcist/dcist_ws/src/MOCHA/mocha_core/config/topic_configs.yaml" \
	-v "./mocha_config/watchstate:/home/dcist/dcist_ws/src/MOCHA/interface_rajant/scripts/thirdParty/watchstate" \
	-v "./data/zed_calib:/usr/local/zed/settings/" \
	--security-opt seccomp=unconfined \
	--group-add=dialout \
	--privileged \
	--rm \
	-it llm_planning bash
		

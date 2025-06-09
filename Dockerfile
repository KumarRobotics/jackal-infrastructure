FROM kumarrobotics/dcist-master-nvda:latest

RUN sudo apt-get update && sudo apt-get install ros-noetic-navigation ros-noetic-realsense2-camera -y

# Dealing with SSH keys. thanks yuezhan
ARG ssh_prv_key
ARG ssh_pub_key
RUN sudo apt-get install -y openssh-server 


# Authorize SSH Host
RUN mkdir -p /home/dcist/.ssh && \
    chmod 0700 /home/dcist/.ssh
# COPY known_hosts > /root/.ssh/anown_hosts

# Add the keys and set permissions
RUN echo "$ssh_prv_key" > /home/dcist/.ssh/id_rsa && \
    echo "$ssh_pub_key" > /home/dcist/.ssh/id_rsa.pub && \
    chmod 600 /home/dcist/.ssh/id_rsa && \
    chmod 600 /home/dcist/.ssh/id_rsa.pub
RUN eval `ssh-agent -s`
RUN ssh-keyscan github.com >> /home/dcist/.ssh/known_hosts

RUN sudo apt install -y     \
    build-essential         \
    libeigen3-dev           \
    libjsoncpp-dev          \
    libspdlog-dev           \
    libcurl4-openssl-dev    \
    cmake                 

RUN sudo apt-get install ros-noetic-rosbridge-server -y

# install miniconda
RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /home/dcist/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 

RUN sh /home/dcist/miniconda3/etc/profile.d/conda.sh \
    && echo "source /home/dcist/miniconda3/etc/profile.d/conda.sh" >> /home/dcist/.bashrc \
    && echo "export PATH=/home/dcist/miniconda3/bin:$PATH" >> /home/dcist/.bashrc

RUN /home/dcist/miniconda3/bin/conda install python=3.10 ipython -y

# point catkin to anaconda env so we have more control over python deps
RUN cd /home/dcist/dcist_ws && catkin config -DCMAKE_BUILD_TYPE=Release \
 -DPYTHON_EXECUTABLE=/home/dcist/miniconda3/bin/python3 \
 -DYPTHON_LIBRARY=/home/dcist/miniconda3/lib/libpython3.10.so \
 -DPYTHON_INCLUDE_DIR=/home/dcist/miniconda3/include/python3.10/

# install python deps
# note there are some overwrites / redundancies that need to be cleaned up
RUN /home/dcist/miniconda3/bin/pip install openai networkx scipy ultralytics opencv-python rosbags netifaces utm gtsam zmq
RUN /home/dcist/miniconda3/bin/pip install empy==3.3.4 catkin_pkg pyyaml numpy==1.21 rospkg defusedxml twisted pyopenssl autobahn tornado pymongo Pillow service-identity
RUN /home/dcist/miniconda3/bin/pip install pyrealsense2 numpy==1.24 pyrealsense2 transformers bitsandbytes accelerate

# clone ouster, faster lio
RUN rm -rf /home/dcist/dcist_ws/src/ouster_example && rm -rf /home/dcist/dcist_ws/src/jackal  && cd /home/dcist/dcist_ws && catkin clean -y
RUN cd /home/dcist/dcist_ws/src &&  git clone --recurse-submodules git@github.com:tyuezhan/ouster-ros.git -b v0.10.0/jackal
RUN cd /home/dcist/dcist_ws/src && git clone --recursive git@github.com:tyuezhan/faster-lio.git

# zed camera
RUN sudo apt update
RUN sudo apt-get install  -y libnvidia-encode-470 libnvidia-decode-470
RUN sudo apt install -y zstd
RUN wget https://download.stereolabs.com/zedsdk/4.2/cu11/ubuntu20 && chmod +x ubuntu20 && ./ubuntu20 -- silent

RUN cd /home/dcist/dcist_ws/src/ && git clone --recursive https://github.com/KumarRobotics/zed-ros-wrapper.git -b no-tf-publish
RUN cd /home/dcist/dcist_ws/ && . /opt/ros/noetic/setup.sh && rosdep update && rosdep install --from-paths . --ignore-src -r -y

RUN cd /home/dcist/dcist_ws && catkin build 

# install grounding dino
RUN mkdir /home/dcist/packages \
    && cd /home/dcist/packages \
    && git clone git@github.com:ZacRavichandran/GroundingDino.git  \
    &&  /home/dcist/miniconda3/bin/pip install -e GroundingDino/.

# copy models onto image 
# we want to do this early b/c this is an expensive call, so put them in tmp dir 
# then move after we install gronding dino
RUN mkdir /home/dcist/tmp_gd_checkpoints
COPY ./data/GroundingDINO_SwinT_OGC.py /home/dcist/tmp_gd_checkpoints/
COPY ./data/groundingdino_swint_ogc.pth /home/dcist/tmp_gd_checkpoints/
COPY ./data/huggingface/. /home/dcist/.cache/huggingface

# needs to be moved up TODO
RUN /home/dcist/miniconda3/bin/pip install supervision==0.21.0 
RUN /home/dcist/miniconda3/bin/pip install torch==2.3.0 torchvision==0.18.0 torchaudio==2.3.0 --index-url https://download.pytorch.org/whl/cu121

# ground estimation
RUN sudo apt-get update -y
RUN sudo apt-get install -y ros-noetic-grid-map-core ros-noetic-grid-map-ros \
	ros-noetic-grid-map-filters \
	ros-noetic-grid-map-loader \
	ros-noetic-grid-map-rviz-plugin \
	ros-noetic-grid-map-visualization 
RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:ZacRavichandran/groundgrid.git

RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:KumarRobotics/imu_vn_100.git && catkin build 

# sys config
RUN sudo chown -R dcist /home/dcist/.cache/huggingface
RUN echo 'source /home/dcist/dcist_ws/devel/setup.bash' >> ~/.bashrc

# detection, etc.
RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:ZacRavichandran/open-vocab-vision-ros.git -b tfr24 && catkin build 
RUN cd /home/dcist/dcist_ws/src/open-vocab-vision-ros/checkpoints && wget https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8x-worldv2.pt

# we put checkpoints in staging area b/c they are large and we don't want to redo copy to image every time we rebuild docker 
RUN mv /home/dcist/tmp_gd_checkpoints/* /home/dcist/dcist_ws/src/open-vocab-vision-ros/checkpoints/

RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:KumarRobotics/ublox.git -b jackal && sudo apt-get install ros-noetic-rtcm-msgs && catkin build 

# for jackal updates
RUN echo 'update 1'
RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:ZacRavichandran/jackal.git -b gain-tune  && catkin build 

# MOCHA deps install
RUN sudo apt update \
 && pip3 install rospkg \
 && pip3 install defusedxml \
 && sudo apt install -y python3-zmq 

RUN sudo apt install -y default-jre
RUN sudo apt-get install -y iputils-ping

# MOCHA ros install
RUN cd /home/dcist/dcist_ws/src \
 && git clone https://github.com/KumarRobotics/MOCHA

# llm planning and launch stuff
RUN echo "update 2"
RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:KumarRobotics/jackal-infrastructure.git
RUN cd /home/dcist/dcist_ws/src && git clone git@github.com:KumarRobotics/llm-planning.git  && /home/dcist/miniconda3/bin/pip install -e llm-planning/. && catkin build 
RUN cd /home/dcist/dcist_ws/src/open-vocab-vision-ros && git pull  && catkin build

RUN echo "export ROS_IP=127.0.0.1" >> /home/dcist/.bashrc
RUN echo "export ROS_MASTER_URI=http://127.0.0.1:11311" >> /home/dcist/.bashrc



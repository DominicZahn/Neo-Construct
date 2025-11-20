FROM ros:jazzy
ENV ROS_DISTRO=jazzy

# General packages
SHELL ["/bin/bash", "-c" ]
RUN apt-get update && apt-get install -y \
  x11-apps \
  gdb \
  nano \
  tmux \
  htop \
  nvtop \
  git \
  sudo \
  wget \
  gnupg2 \
  mesa-utils

# ROS2 packages
RUN apt-get update && apt-get install -y \
  ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
  ros-${ROS_DISTRO}-rosidl-generator-dds-idl \
  ros-${ROS_DISTRO}-geometry-msgs \
  ros-${ROS_DISTRO}-ros-gz \
  ros-${ROS_DISTRO}-ros-gz-sim \
  ros-${ROS_DISTRO}-ros-gz-bridge \
  ros-${ROS_DISTRO}-ros2-control \
  ros-${ROS_DISTRO}-ament-cmake \
  ros-${ROS_DISTRO}-tf2-ros \
  ros-${ROS_DISTRO}-tf2-geometry-msgs \
  ros-${ROS_DISTRO}-joint-state-publisher-gui \
  python3-colcon-common-extensions \
  python3-vcstool

# RBDL packages
RUN apt-get update && apt-get install -y \
  libeigen3-dev \
  cython3 \
  libopencv-dev \
  libtinyxml2-dev

RUN rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive

# Create user robot
RUN useradd -m -s /bin/bash robot && echo "robot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER robot

# Setup workspace
WORKDIR /home/robot/ws

# minconda
RUN mkdir -p ~/miniconda3 \
  && wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh \
  && bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3 \
  && rm ~/miniconda3/miniconda.sh
RUN source ~/miniconda3/bin/activate \
  && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r \
  && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main

# RBDL
RUN git clone --recursive https://github.com/rbdl/rbdl /home/robot/rbdl
RUN cd /home/robot/rbdl/ && git submodule init && git submodule update
RUN mkdir -p /home/robot/rbdl/build/ && cd /home/robot/rbdl/build/ && \
  cmake -D CMAKE_BUILD_TYPE=Release .. && \
  cmake -D RBDL_BUILD_ADDON_URDFREADER=ON .. && \
  cmake -D RBDL_BUILD_PYTHON_WRAPPER=ON .. && \
  cmake build . && \
  sudo make install

# nlopt and bioptim
RUN source ~/miniconda3/bin/activate \
  && conda install -c conda-forge python=3.12 bioptim python pygame catkin_pkg \
  && pip3 install opencv-python

RUN git clone https://github.com/stevengj/nlopt.git /home/robot/nlopt
RUN mkdir -p /home/robot/nlopt/build && cd /home/robot/nlopt/build && \
  cmake .. && \
  cmake build . && \
  sudo make install

# bashrc
RUN printf '%s\n' \
  'export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH' \
  'export TERM=xterm-256color' \
  'source /opt/ros/${ROS_DISTRO}/setup.bash' \
  'source /home/robot/ws/install/setup.bash' \
  'source ~/miniconda3/bin/activate' \
  "alias build='cd /home/robot/ws/ && colcon build --parallel-workers 10 --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo && source install/setup.bash'" \
  >> /home/robot/.bashrc

RUN printf '%s\n' \
  'export PYTHONPATH=$PYTHONPATH:/home/robot/rbdl/build/python' \
  >> /home/robot/.bashrc

# GPU plugins in Gazebo
ENV IGN_RENDER_ENGINE=ogre2
ENV OGRE2_RENDER_SYSTEM=gl

# X11 forwarding
ENV DISPLAY=:1
ENV QT_X11_NO_MITSHM=1
ENV XAUTHORITY=/tmp/.docker.xauth

SHELL [ "/bin/bash", "-c" ]
CMD ["tmux"]

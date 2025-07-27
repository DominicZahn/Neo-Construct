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

RUN rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive

# Create user robot
RUN useradd -m -s /bin/bash robot && echo "robot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER robot

# Setup workspace
WORKDIR /home/robot/ws

# minconda
RUN mkdir -p ~/miniconda3
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
RUN bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
RUN rm ~/miniconda3/miniconda.sh
RUN source ~/miniconda3/bin/activate \
  && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r \
  && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main

# biorbd and nlopt
RUN source ~/miniconda3/bin/activate \
  && conda install -c conda-forge python pygame biorbd nlopt catkin_pkg

# bashrc
RUN printf '%s\n' \
'export TERM=xterm-256color' \
'source /opt/ros/${ROS_DISTRO}/setup.bash' \
'source /home/robot/ws/install/setup.bash' \
'source ~/miniconda3/bin/activate' \
"alias build='cd /home/robot/ws/ && colcon build --parallel-workers 4 --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo && source install/setup.bash'" \
>> /home/robot/.bashrc

# GPU plugins in Gazebo
ENV IGN_RENDER_ENGINE=ogre2
ENV OGRE2_RENDER_SYSTEM=gl

# X11 forwarding
ENV DISPLAY=:1
ENV QT_X11_NO_MITSHM=1
ENV XAUTHORITY=/tmp/.docker.xauth

SHELL [ "bin/bash", "-c" ]
CMD ["tmux"]

FROM ros:jazzy
ENV ROS_DISTRO=jazzy

# General packages
SHELL ["/bin/bash", "-c" ]
RUN apt-get update && apt-get install -y \
  x11-apps \
  gdb \
  nano \
  vim \
  tmux \
  htop \
  nvtop \
  git \
  sudo \
  wget \
  gnupg2 \
  cmake \
  cmake-curses-gui \
  cython3 \
  libeigen3-dev \
  libtinyxml-dev \
  liburdfdom-dev \
  liburdfdom-headers-dev \
  pkg-config \
  python3-full \
  python3-pip \
  python3-numpy

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

# robotpkg
RUN mkdir -p /etc/apt/keyrings && \
  curl http://robotpkg.openrobots.org/packages/debian/robotpkg.asc | tee /etc/apt/keyrings/robotpkg.asc && \
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/robotpkg.asc] http://robotpkg.openrobots.org/packages/debian/pub $(lsb_release -cs) robotpkg" | tee /etc/apt/sources.list.d/robotpkg.list && \
  apt-get update

# rbdl with urdfreader
ENV RBDL_DIR=/opt/rbdl
WORKDIR ${RBDL_DIR}
RUN git clone --recursive https://github.com/rbdl/rbdl /opt/rbdl
RUN git submodule init && git submodule update
WORKDIR ${RBDL_DIR}/build
RUN cmake -D CMAKE_BUILD_TYPE=Release .. && \
  cmake -D RBDL_BUILD_ADDON_URDFREADER=ON .. && \
  cmake -D RBDL_BUILD_PYTHON_WRAPPER=ON .. && \
  cmake build . && \
  make -j$(nproc) && \
  make install

# nlopt
ENV NLOPT_DIR=/opt/nlopt
RUN git clone https://github.com/stevengj/nlopt.git /opt/nlopt
WORKDIR ${NLOPT_DIR}/build
RUN cmake .. && \
  cmake build . && \
  make -j$(nproc) && \
  make install

# acados
ENV ACADOS_DIR=/opt/acados
RUN git clone https://github.com/acados/acados.git /opt/acados
WORKDIR ${ACADOS_DIR}
RUN git submodule update --recursive --init
WORKDIR ${ACADOS_DIR}/build
RUN cmake -D ACADOS_WITH_QPOASES=ON .. && \
  cmake -D ACADOS_WITH_DAQP=ON .. && \
  # cmake -D ACADOS_WITH_HPMPC=OFF .. && \
  # cmake -D HPIPM_TARGET=GENERIC .. && \
  cmake -D ACADOS_WITH_OPENMP=ON .. && \
  cmake -D ACADOS_EXAMPLES=ON .. && \
  make -j$(nproc) && \
  make install

# acados python
WORKDIR ${ACADOS_DIR}
# RUN python3 -m venv ac_env && \
# source ac_env/bin/activate && \
RUN pip install -e interfaces/acados_template --break-system-packages
RUN wget https://github.com/acados/tera_renderer/releases/download/v0.2.0/t_renderer-v0.2.0-linux-amd64 && \
  mv t_renderer-v0.2.0-linux-amd64 bin/t_renderer && \
  chmod +x bin/t_renderer

# pinocchio
RUN apt-get install robotpkg-py312-pinocchio -y

# clean up
RUN rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive

# Create user robot
RUN useradd -m -s /bin/bash robot && echo "robot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER robot

# Setup workspace
WORKDIR /home/robot/ws

# bashrc
RUN printf '%s\n' \
  'export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH' \
  'export TERM=xterm-256color' \
  'source /opt/ros/${ROS_DISTRO}/setup.bash' \
  'source /home/robot/ws/install/setup.bash' \
  "alias build='cd /home/robot/ws/ && colcon build --parallel-workers 10 --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo && source install/setup.bash'" \
  "alias lsa='ls -la'" \
  '# acados' \
  'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ACADOS_DIR/lib' \
  'export ACADOS_SOURCE_DIR=$ACADOS_DIR' \
  '# pinocchio' \
  'export PATH=/opt/openrobots/bin:$PATH' \
  'export PKG_CONFIG_PATH=/opt/openrobots/lib/pkgconfig:$PKG_CONFIG_PATH' \
  'export LD_LIBRARY_PATH=/opt/openrobots/lib:$LD_LIBRARY_PATH' \
  'export PYTHONPATH=/opt/openrobots/lib/python3.12/site-packages:$PYTHONPATH' \
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

FROM ros:jazzy
ENV ROS_DISTRO=jazzy

ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/
ENV PKG_CONFIG_PATH=""
ENV PYTHONPATH=""
ENV CMAKE_PREFIX_PATH=""

# General packages
SHELL ["/bin/bash", "-c" ]
RUN apt-get update && apt-get install -y \
  gosu \
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
  libomp-dev \
  libeigen3-dev \
  libtinyxml-dev \
  liburdfdom-dev \
  liburdfdom-headers-dev \
  pkg-config \
  swig \
  python3-full \
  python3-pip

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
  ros-${ROS_DISTRO}-rqt* \
  python3-colcon-common-extensions \
  python3-vcstool

ENV LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH

# setup python venv -> use /opt/venv/bin/pip instead of pip !!!!
RUN python3 -m venv /opt/venv --system-site-packages
ENV PATH=/opt/venv/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/venv/lib:/opt/venv:$LD_LIBRARY_PATH
ENV PYTHONPATH=/opt/venv/lib/python3.12/site-packages:$PYTHONPATH

# rbdl with urdfreader
ENV RBDL_DIR=/opt/rbdl
WORKDIR $RBDL_DIR
RUN git clone --recursive https://github.com/rbdl/rbdl /opt/rbdl && \
  git submodule init && git submodule update
RUN /opt/venv/bin/pip install numpy scipy matplotlib
WORKDIR $RBDL_DIR/build
RUN source /opt/venv/bin/activate && \
  cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/venv/ \
  -DRBDL_BUILD_ADDON_URDFREADER=ON  \
  -DRBDL_BUILD_PYTHON_WRAPPER=ON \
  cmake build . && \
  make -j$(nproc) && \
  make install
ENV PYTHONPATH=${PYTHONPATH}:${RBDL_DIR}/build/python

# nlopt
ENV NLOPT_DIR=/opt/nlopt
RUN git clone https://github.com/stevengj/nlopt.git /opt/nlopt
WORKDIR ${NLOPT_DIR}/build
RUN source /opt/venv/bin/activate && \
  cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/venv/ \
  -DPYTHON_EXECUTABLE=/opt/venv/bin/python && \
  make -j$(nproc) && \
  make install
ENV PYTHONPATH=${PYTHONPATH}:${NLOPT_DIR}/build/python

# pinocchio
# --- optional dependencies: apt packages
RUN apt-get update && apt-get install -y \
  libboost-python-dev \
  libboost-serialization-dev \
  libassimp-dev \
  liboctomap-dev \
  libqhull-dev
RUN /opt/venv/bin/pip install \
  hpp-fcl \
  eigenpy \
  pybind11-stubgen

# --- CppAD
WORKDIR /opt/cppad
RUN git clone https://github.com/coin-or/CppAD.git . && \
  mkdir build && cd build && \
  cmake .. \
  -DCMAKE_INSTALL_PREFIX=/opt/venv \
  -DCMAKE_BUILD_TYPE=Release && \
  make -j$(nproc) && \
  make install

# --- CppADCodeGen
WORKDIR /opt/cppadcodegen
RUN git clone https://github.com/joaoleal/CppADCodeGen.git . && \
  mkdir build && cd build && \
  cmake .. \
  -DCMAKE_INSTALL_PREFIX=/opt/venv \
  -DCMAKE_BUILD_TYPE=Release \
  -DCppAD_DIR=/opt/venv && \
  make -j$(nproc) && \
  make install

# --- casadi
ENV CASADI_DIR=/opt/casadi
WORKDIR ${CASADI_DIR}
RUN git clone --depth 1 --branch 3.7.2 https://github.com/casadi/casadi.git . && \
  mkdir build && cd build && \
  cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/venv \
  -DWITH_PYTHON=ON \
  -DWITH_PYTHON3=ON \
  -DPYTHON_EXECUTABLE=/opt/venv/bin/python \
  -DWITH_OPENMP=ON \
  -DWITH_THREAD=ON && \
  make -j$(nproc) && \
  make install

# --- eigenpy
ENV EIGENPY_DIR=/opt/eigenpy
WORKDIR ${EIGENPY_DIR}
RUN git clone --recursive https://github.com/stack-of-tasks/eigenpy.git . && \
  mkdir build && cd build && \
  cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/venv \
  -DPYTHON_EXECUTABLE=/opt/venv/bin/python \
  -DBUILD_PYTHON_INTERFACE=ON && \
  make -j4 && \
  make install

# --- coal
RUN apt-get install -y \
  libboost-serialization-dev \
  libboost-filesystem-dev \
  libboost-test-dev \
  libboost-python-dev \
  libqhull-dev \
  liboctomap-dev
ENV COAL_DIR=/opt/coal
WORKDIR ${COAL_DIR}
RUN git clone --recursive https://github.com/coal-library/coal.git . && \
  mkdir build && cd build && \
  . /opt/venv/bin/activate && \
  cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/venv \
  -DPYTHON_EXECUTABLE=/opt/venv/bin/python \
  -DBUILD_PYTHON_INTERFACE=ON \
  -DCOAL_HAS_QHULL=ON && \
  make -j$(nproc) && \
  make install

# --- pinocchio
ENV PINOCCHIO_DIR=/opt/pinocchio
WORKDIR ${PINOCCHIO_DIR}
RUN git clone --depth 1 --branch v4.0.0 --recursive https://github.com/stack-of-tasks/pinocchio.git . && \
  mkdir build && cd build && \
  source /opt/venv/bin/activate && \
  cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/venv \
  -DPYTHON_EXECUTABLE=/opt/venv/bin/python \
  -DBUILD_PYTHON_INTERFACE=ON \
  -DGENERATE_PYTHON_STUBS=ON \
  -DBUILD_WITH_CASADI_SUPPORT=ON \
  -DBUILD_WITH_COLLISION_SUPPORT=ON \
  -DBUILD_WITH_URDF_SUPPORT=ON \
  -DBUILD_WITH_OPENMP_SUPPORT=ON \
  -DBUILD_WITH_AUTODIFF_SUPPORT=ON \
  -DBUILD_WITH_CODEGEN_SUPPORT=ON && \
  make -j2 && \
  make install
ENV EXAMPLE_ROBOT_DATA_MODEL_DIR=${PINOCCHIO_DIR}/models/example-robot-data/robots/

# meshcat (visualizer)
RUN /opt/venv/bin/pip install meshcat

# acados
ENV ACADOS_DIR=/opt/acados
RUN git clone --depth 1 --branch v0.5.3 https://github.com/acados/acados.git /opt/acados
WORKDIR ${ACADOS_DIR}
RUN git submodule update --recursive --init
WORKDIR ${ACADOS_DIR}/build
RUN cmake .. \
  -DACADOS_WITH_QPOASES=ON \
  -DACADOS_WITH_DAQP=ON \
  -DACADOS_WITH_OPENMP=ON \
  -DACADOS_EXAMPLES=ON && \
  make -j$(nproc) && \
  make install

# acados python
WORKDIR ${ACADOS_DIR}
RUN /opt/venv/bin/pip install numpy scipy matplotlib Deprecated
RUN /opt/venv/bin/pip install -e interfaces/acados_template --no-deps
RUN wget https://github.com/acados/tera_renderer/releases/download/v0.2.0/t_renderer-v0.2.0-linux-amd64 && \
  mv t_renderer-v0.2.0-linux-amd64 bin/t_renderer && \
  chmod +x bin/t_renderer

ENV PYTHONPATH=$ACADOS_DIR/interfaces/acados_template:$PYTHONPATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ACADOS_DIR/lib
ENV ACADOS_SOURCE_DIR=$ACADOS_DIR

# clean up
RUN rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=noninteractive

# workspace
WORKDIR /home/robot/ws
COPY .bash_profile_template /home/robot/.bash_profile
RUN chmod +x /home/robot/.bash_profile
COPY .tmux.conf /home/robot/.tmux.conf

# GPU plugins in Gazebo
ENV IGN_RENDER_ENGINE=ogre2
ENV OGRE2_RENDER_SYSTEM=gl

# X11 forwarding
ENV DISPLAY=:1
ENV QT_X11_NO_MITSHM=1
ENV XAUTHORITY=/tmp/.docker.xauth

# entrypoint for user switch
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh
ENTRYPOINT [ "/opt/entrypoint.sh" ]
CMD [ "tmux" ]

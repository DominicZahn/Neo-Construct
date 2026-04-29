<div align="center">
<h1>🥋 Neo Construct 🧰</h1>
</div>

A ready-to-go robotics optimal control setup in the form of a [Docker](https://www.docker.com/) container.
The Neo Construct encapsulates a whole [ROS2](https://github.com/ros2) [Gazebo Jetty](https://gazebosim.org/docs/latest/ros2_integration/) environment to solve robotics problems with a pipeline of [Acados](https://docs.acados.org/) and [Pinocchio](https://stack-of-tasks.github.io/pinocchio/).

It only uses Docker and Make to manage the Docker.
So this setup can be used directly from the command line without requiring any additional software.

## Quick Start
>
> TODO
>
### Docker Build

#### Requirements

- [Docker](https://www.docker.com/)
- [GNU Make](https://www.gnu.org/software/make/)
- (for NVIDIA GPUs) [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- internet connection

### Run

## Usage

### Structure

```
.
|-+-- ws
| |   +-- src
| |   |   +-- (*)
| |   +-- ext_pkgs
| |   |   +-- (**)
| |   |
| |   +-- build
| |   +-- install
| |   +-- log
| |
| +-- Dockerfile
| +-- Makefile
| +-- .gitignore
| +-- README.md
|
+-- ext_pkgs (**)

(*) your ROS2 project goes here
(**) alows to mount external packages into the docker
```

### Docker Management

The docker is managed by the [Makefile](/Makefile). The four commands bundle some arguments and management commands together to create a more friendly Docker experience.

| Command | Description |
|---------|-------------|
| `run` | launches the docker with `docker run` and enables X11-forwarding on the host machine |
| `build` | calls `docker build` with the correct container name |
| `clean` | removes colcon artifacts in `ws` and deletes Docker from the internal list <br> -> full `build` is necessary! |
| `rebuild` | combination of `clean` and `build` without the use of cache |
| `stop` | can be used to stop the docker when the process where `run` was called is not accessible (calls `docker stop`) |

Most of the time you will use `make build` once and then only launch the docker with `make run`.
A rebuild is only adjusted if the container configuration inside the [Dockerfile](/Dockerfile) was adjusted.

### Inside the Workspace

The main project and ROS2 packages are put inside the [src](/ws/src/) directory.
It is mounted directly into the Docker, so everything in here will be synced in both directions.

To build everything, the alias `build` can be used inside the container to move to the parent workspace folder (`ws`) and then execute `colcon build --symlink-install`. With this setup, the problem of creating random colcon artifacts is a thing of the past.

### Testing

> TO REWRITE

To test if everything is setup a correctly, it is recommended to clone the [ros2_heinz](https://github.com/K-d4wg/ros2_heinz.git) repository inside the [src](/ws/src/) directory.
Follow the instructions of the repository to see if the workspace behaves as expected.

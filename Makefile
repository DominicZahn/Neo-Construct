ROS_DISTRO=jazzy
CONTAINER_NAME=neo-construct
GPU:=$(shell command -v nvidia-smi >/dev/null 2>&1 && echo true || echo false)
HOST_UID=$(shell id -u)
HOST_GID=$(shell id -g)

build:
	mkdir -p $(CURDIR)/ws/src
	docker build -t $(CONTAINER_NAME) .

run:
	xhost +local:docker
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -it \
		--hostname $(CONTAINER_NAME) \
		$(if $(filter true, $(GPU)),--gpus all --runtime=nvidia --env="NVIDIA_VISIBLE_DEVICES=all" --env="NVIDIA_DRIVER_CAPABILITIES=all",) \
		--env HOST_UID=$(HOST_UID) \
		--env HOST_GID=$(HOST_GID) \
		--env "DISPLAY" \
		--env "QT_X11_NO_MITSHM=1" \
		--net=host \
		--device=/dev/dri/ \
		--mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix \
		--mount type=bind,src=$(CURDIR)/ws,dst=/home/robot/ws \
		$(shell [ -d $(CURDIR)/../ext_pkgs ] && echo "--mount type=bind,src=$(CURDIR)/../ext_pkgs,dst=/home/robot/ws/ext_pkgs") \
		--name $(CONTAINER_NAME) \
		$(CONTAINER_NAME)
stop:
	-docker stop $(CONTAINER_NAME) || true

clean:
	rm -rf $(CURDIR)/ws/build/
	rm -rf $(CURDIR)/ws/install/
	rm -rf $(CURDIR)/ws/log/
	-docker rmi -f $(CONTAINER_NAME) 2>/dev/null || true
rebuild:
	$(MAKE) clean
	docker build --no-cache -t $(CONTAINER_NAME) .

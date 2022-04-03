FROM nvidia/cuda:11.6.0-runtime-ubuntu18.04 as base
USER root
ENV NV_CUDA_LIB_VERSION "11.6.0-1"

FROM base as base-amd64

ENV NV_CUDA_CUDART_DEV_VERSION 11.6.55-1
ENV NV_NVML_DEV_VERSION 11.6.55-1
ENV NV_LIBCUSPARSE_DEV_VERSION 11.7.1.55-1
ENV NV_LIBNPP_DEV_VERSION 11.6.0.55-1
ENV NV_LIBNPP_DEV_PACKAGE libnpp-dev-11-6=${NV_LIBNPP_DEV_VERSION}

ENV NV_LIBCUBLAS_DEV_VERSION 11.8.1.74-1
ENV NV_LIBCUBLAS_DEV_PACKAGE_NAME libcublas-dev-11-6
ENV NV_LIBCUBLAS_DEV_PACKAGE ${NV_LIBCUBLAS_DEV_PACKAGE_NAME}=${NV_LIBCUBLAS_DEV_VERSION}

ENV NV_LIBNCCL_DEV_PACKAGE_NAME libnccl-dev
ENV NV_LIBNCCL_DEV_PACKAGE_VERSION 2.11.4-1
ENV NCCL_VERSION 2.11.4-1
ENV NV_LIBNCCL_DEV_PACKAGE ${NV_LIBNCCL_DEV_PACKAGE_NAME}=${NV_LIBNCCL_DEV_PACKAGE_VERSION}+cuda11.6

FROM base as base-arm64

ENV NV_CUDA_CUDART_DEV_VERSION 11.6.55-1
ENV NV_NVML_DEV_VERSION 11.6.55-1
ENV NV_LIBCUSPARSE_DEV_VERSION 11.7.1.55-1
ENV NV_LIBNPP_DEV_VERSION 11.6.0.55-1
ENV NV_LIBNPP_DEV_PACKAGE libnpp-dev-11-6=${NV_LIBNPP_DEV_VERSION}

ENV NV_LIBCUBLAS_DEV_PACKAGE_NAME libcublas-dev-11-6
ENV NV_LIBCUBLAS_DEV_VERSION 11.8.1.74-1
ENV NV_LIBCUBLAS_DEV_PACKAGE ${NV_LIBCUBLAS_DEV_PACKAGE_NAME}=${NV_LIBCUBLAS_DEV_VERSION}

FROM base-amd64


LABEL maintainer "NVIDIA CORPORATION <cudatools@nvidia.com>"

RUN apt-get update && apt-get install -y git && \
    apt-get -y install sudo \
    cuda-cudart-dev-11-6=${NV_CUDA_CUDART_DEV_VERSION} \
    cuda-command-line-tools-11-6=${NV_CUDA_LIB_VERSION} \
    cuda-minimal-build-11-6=${NV_CUDA_LIB_VERSION} \
    cuda-libraries-dev-11-6=${NV_CUDA_LIB_VERSION} \
    cuda-nvml-dev-11-6=${NV_NVML_DEV_VERSION} \
    ${NV_LIBNPP_DEV_PACKAGE} \
    libcusparse-dev-11-6=${NV_LIBCUSPARSE_DEV_VERSION} \
    ${NV_LIBCUBLAS_DEV_PACKAGE} \
    ${NV_LIBNCCL_DEV_PACKAGE}

# Keep apt from auto upgrading the cublas and nccl packages. See https://gitlab.com/nvidia/container-images/cuda/-/issues/88
RUN apt-mark hold ${NV_LIBCUBLAS_DEV_PACKAGE_NAME} ${NV_LIBNCCL_DEV_PACKAGE_NAME}

# #Setup agv USER
RUN groupadd -g 1000 agv && \
    useradd -d /home/agv -s /bin/bash -m agv -u 1000 -g 1000 && \
    usermod -aG sudo agv && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers 

USER agv
RUN mkdir -p /home/agv/alpha_ws/src
ENV HOME /home/agv
WORKDIR /home/agv/alpha_ws/
RUN git clone https://github.com/f1tenth/f1tenth_simulator.git

ARG ROS_PKG=ros_base
ENV ROS_DISTRO=melodic
ENV ROS_ROOT=/opt/ros/${ROS_DISTRO}

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /workspace


# 
# add the ROS deb repo to the apt sources list
#
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
          git \
		cmake \
		build-essential \
		curl \
		python-pip \
		gedit \
		wget \
		gnupg2 \
		lsb-release \
		ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -


# 
# install ROS packages
#
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
		ros-melodic-desktop-full \
		ros-melodic-image-transport \
		ros-melodic-vision-msgs \
          python-rosdep \
          python-rosinstall \
          python-rosinstall-generator \
          python-wstool \
    && rm -rf /var/lib/apt/lists/*


#
# init/update rosdep
#
RUN apt-get update && \
    cd ${ROS_ROOT} && \
    rosdep init && \
    rosdep update && \
    rm -rf /var/lib/apt/lists/*


# 
# setup entrypoint
#
COPY ./ros_entrypoint.sh /ros_entrypoint.sh
COPY src .
RUN bash -c "chmod +x /ros_entrypoint.sh"
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
WORKDIR /
RUN sudo apt-get update
RUN sudo apt-get install -y ros-melodic-ackermann-msgs ros-melodic-laser-filters ros-melodic-gazebo-ros libgazebo9-dev ros-melodic-joint-limits-interface ros-melodic-ros-control ros-melodic-rviz ros-melodic-xacro ros-melodic-map-server ros-melodic-catkin python-catkin-tools ros-melodic-base-local-planner ros-melodic-tf2-geometry-msgs    
RUN echo 'source /opt/ros/melodic/setup.bash' >> ~/.bashrc 
RUN echo 'sudo chmod 777 -R ~/.ros/' >> ~/.bashrc
ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs

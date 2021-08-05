# Copyright (C) 2019-2021 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
FROM ubuntu:20.04 AS base

# hadolint ignore=DL3002
USER root
WORKDIR /

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tzdata ca-certificates && \
    rm -rf /var/lib/apt/lists/*


# get product from local archive
ARG package_url
ARG TEMP_DIR=/tmp/openvino_installer

WORKDIR ${TEMP_DIR}
COPY ${package_url} ${TEMP_DIR}

# install product by installation script
ENV INTEL_OPENVINO_DIR /opt/intel/openvino

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends cpio && \
    rm -rf /var/lib/apt/lists/* && \
    tar -xzf ${TEMP_DIR}/*.tgz --strip 1 && \
    sed -i 's/decline/accept/g' silent.cfg && \
    ${TEMP_DIR}/install.sh -s silent.cfg && \
    OV_BUILD="$(find /opt/intel -maxdepth 1 -type d -name "*openvino*" | grep -oP '(?<=_)\d+.\d+.\d+')" && \
    ln --symbolic /opt/intel/openvino_"$OV_BUILD"/ /opt/intel/openvino && rm -rf ${TEMP_DIR} && \
    rm -rf ${INTEL_OPENVINO_DIR}/deployment_tools/tools/workbench

# install vim 
RUN apt-get update \
    && apt-get install -y \
        nmap \
        vim

ARG models_url
COPY ${models_url} ${TEMP_DIR}

RUN tar -C /opt/intel -xzf ${models_url}

# for VPU
ARG BUILD_DEPENDENCIES="autoconf \
                        automake \
                        build-essential \
                        libtool \
                        unzip"

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends ${BUILD_DEPENDENCIES} && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN curl -L https://github.com/libusb/libusb/archive/v1.0.22.zip --output v1.0.22.zip && \
    unzip v1.0.22.zip && rm -rf v1.0.22.zip

WORKDIR /opt/libusb-1.0.22
RUN ./bootstrap.sh && \
    ./configure --disable-udev --enable-shared && \
    make -j4

# -----------------
FROM ubuntu:20.04 AS ov_base

LABEL Description="This is the proprietary image for Intel(R) Distribution of OpenVINO(TM) toolkit on Ubuntu 20.04 LTS"
LABEL Vendor="Intel Corporation"

USER root
WORKDIR /

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Creating user openvino and adding it to groups "video" and "users" to use GPU and VPU
RUN useradd -ms /bin/bash -G video,users openvino && \
    chown openvino -R /home/openvino

RUN mkdir /opt/intel

ENV INTEL_OPENVINO_DIR /opt/intel/openvino

COPY --from=base /opt/intel /opt/intel

WORKDIR /thirdparty

ARG INSTALL_SOURCES="no"
ARG accuracy_checker="no"
ARG pot="no"



ARG DEPS="tzdata \
          curl"

ARG LGPL_DEPS="g++ \
               gcc \
               libc6-dev"
ARG INSTALL_PACKAGES="-c=opencv_req -c=python -c=cl_compiler -c=opencv_opt -c=dlstreamer -c=pot"



# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends dpkg-dev && \
    dpkg --get-selections | grep -v deinstall | awk '{print $1}' > base_packages.txt  && \
    apt-get install -y --no-install-recommends ${DEPS} && \
    rm -rf /var/lib/apt/lists/*


# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends ${LGPL_DEPS} && \
    ${INTEL_OPENVINO_DIR}/install_dependencies/install_openvino_dependencies.sh -y ${INSTALL_PACKAGES} && \
    if [ "$INSTALL_SOURCES" = "yes" ]; then \
      sed -Ei 's/# deb-src /deb-src /' /etc/apt/sources.list && \
      apt-get update && \
	  dpkg --get-selections | grep -v deinstall | awk '{print $1}' > all_packages.txt && \
	  grep -v -f base_packages.txt all_packages.txt | while read line; do \
	  package=`echo $line`; \
	  name=(${package//:/ }); \
      grep -l GPL /usr/share/doc/${name[0]}/copyright; \
      exit_status=$?; \
	  if [ $exit_status -eq 0 ]; then \
	    apt-get source -q --download-only $package;  \
	  fi \
      done && \
      echo "Download source for `ls | wc -l` third-party packages: `du -sh`"; fi && \
    rm -rf /var/lib/apt/lists/*


WORKDIR ${INTEL_OPENVINO_DIR}/licensing
RUN if [ "$INSTALL_SOURCES" = "no" ]; then \
        echo "This image doesn't contain source for 3d party components under LGPL/GPL licenses. Please use tag <YYYY.U_src> to pull the image with downloaded sources." > DockerImage_readme.txt ; \
    fi


# setup Python
ENV PYTHON_VER python3.8



RUN ${PYTHON_VER} -m pip install --upgrade pip
RUN pip install numpy==1.18.5 matplotlib==3.4.2

# proprietary package
WORKDIR /tmp

RUN ${PYTHON_VER} -m pip install --no-cache-dir cmake && \
    ${PYTHON_VER} -m pip install --no-cache-dir -r ${INTEL_OPENVINO_DIR}/python/${PYTHON_VER}/requirements.txt && \
    ${PYTHON_VER} -m pip install --no-cache-dir -r ${INTEL_OPENVINO_DIR}/deployment_tools/tools/benchmark_tool/requirements.txt; \
    if [ -f ${INTEL_OPENVINO_DIR}/data_processing/dl_streamer/requirements.txt ]; then \
        ${PYTHON_VER} -m pip install --no-cache-dir -r ${INTEL_OPENVINO_DIR}/data_processing/dl_streamer/requirements.txt; \
    fi

WORKDIR ${INTEL_OPENVINO_DIR}/deployment_tools/open_model_zoo/tools/accuracy_checker
RUN if [ "$accuracy_checker" = "yes" ]; then \
        source ${INTEL_OPENVINO_DIR}/bin/setupvars.sh && \
        ${PYTHON_VER} -m pip install --no-cache-dir -r ${INTEL_OPENVINO_DIR}/deployment_tools/open_model_zoo/tools/accuracy_checker/requirements.in && \
        ${PYTHON_VER} ${INTEL_OPENVINO_DIR}/deployment_tools/open_model_zoo/tools/accuracy_checker/setup.py install && \
        rm -rf ${INTEL_OPENVINO_DIR}/deployment_tools/open_model_zoo/tools/accuracy_checker/build; \
    fi


# download source for PyPi LGPL packages
WORKDIR /thirdparty
RUN if [ "$INSTALL_SOURCES" = "yes" ]; then \
        curl -L https://files.pythonhosted.org/packages/ee/2d/9cdc2b527e127b4c9db64b86647d567985940ac3698eeabc7ffaccb4ea61/chardet-4.0.0.tar.gz --output chardet-4.0.0.tar.gz; \
        curl -L https://files.pythonhosted.org/packages/81/47/5f2cea0164e77dd40726d83b4c865c2a701f60b73cb6af7b539cd42aafb4/flake8-import-order-0.18.1.tar.gz --output lake8-import-order-0.18.1.tar.gz; \
    fi


WORKDIR ${INTEL_OPENVINO_DIR}/deployment_tools/tools/post_training_optimization_toolkit
RUN if [ "$pot" = "yes" ]; then \
        ${PYTHON_VER} -m pip install --no-cache-dir -r ${INTEL_OPENVINO_DIR}/deployment_tools/tools/post_training_optimization_toolkit/requirements.txt && \
        ${PYTHON_VER} ${INTEL_OPENVINO_DIR}/deployment_tools/tools/post_training_optimization_toolkit/setup.py install --install-extras && \
        rm -rf ${INTEL_OPENVINO_DIR}/deployment_tools/tools/post_training_optimization_toolkit/build; \
    fi

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-gi-cairo  && \
    rm -rf /var/lib/apt/lists/*


# for CPU

# for GPU
ARG INTEL_OPENCL
ARG TEMP_DIR=/tmp/opencl


WORKDIR ${INTEL_OPENVINO_DIR}/install_dependencies
RUN ./install_NEO_OCL_driver.sh --no_numa -y -d ${INTEL_OPENCL} && \
    rm -rf /var/lib/apt/lists/*


# for VPU
ARG LGPL_DEPS=udev

WORKDIR /thirdparty

# hadolint ignore=DL3008
RUN apt-get update && \
    dpkg --get-selections | grep -v deinstall | awk '{print $1}' > no_vpu_packages.txt && \
    apt-get install -y --no-install-recommends ${LGPL_DEPS} && \
    if [ "$INSTALL_SOURCES" = "yes" ]; then \
      sed -Ei 's/# deb-src /deb-src /' /etc/apt/sources.list && \
      apt-get update && \
	  dpkg --get-selections | grep -v deinstall | awk '{print $1}' > vpu_packages.txt && \
	  grep -v -f no_vpu_packages.txt vpu_packages.txt | while read line; do \
	  package=`echo $line`; \
	  name=(${package//:/ }); \
      grep -l GPL /usr/share/doc/${name[0]}/copyright; \
      exit_status=$?; \
	  if [ $exit_status -eq 0 ]; then \
	    apt-get source -q --download-only $package;  \
	  fi \
      done && \
      echo "Download source for `ls | wc -l` third-party packages: `du -sh`"; fi && \
    rm -rf /var/lib/apt/lists/*

COPY --from=base /opt/libusb-1.0.22 /opt/libusb-1.0.22

WORKDIR /opt/libusb-1.0.22/libusb
RUN /bin/mkdir -p '/usr/local/lib' && \
    /bin/bash ../libtool   --mode=install /usr/bin/install -c   libusb-1.0.la '/usr/local/lib' && \
    /bin/mkdir -p '/usr/local/include/libusb-1.0' && \
    /usr/bin/install -c -m 644 libusb.h '/usr/local/include/libusb-1.0' && \
    /bin/mkdir -p '/usr/local/lib/pkgconfig'

WORKDIR /opt/libusb-1.0.22/
RUN /usr/bin/install -c -m 644 libusb-1.0.pc '/usr/local/lib/pkgconfig' && \
    cp ${INTEL_OPENVINO_DIR}/deployment_tools/inference_engine/external/97-myriad-usbboot.rules /etc/udev/rules.d/ && \
    ldconfig

# for HDDL
WORKDIR /tmp
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libboost-filesystem-dev \
        libboost-thread-dev \
        libboost-program-options1.71.0 \
        libjson-c4 \
        libssl1.1 \
        libudev1 \ 
        libelf-dev \
        libxxf86vm-dev && \
    rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*


# Post-installation cleanup and setting up OpenVINO environment variables
RUN if [ -f "${INTEL_OPENVINO_DIR}"/bin/setupvars.sh ]; then \
        printf "\nexport TBB_DIR=\${INTEL_OPENVINO_DIR}/deployment_tools/inference_engine/external/tbb/cmake\n" >> ${INTEL_OPENVINO_DIR}/bin/setupvars.sh; \
        printf "\nsource \${INTEL_OPENVINO_DIR}/bin/setupvars.sh\n" >> /home/openvino/.bashrc; \
        printf "\nsource \${INTEL_OPENVINO_DIR}/bin/setupvars.sh\n" >> /root/.bashrc; \
    fi; \
    if [ -d /opt/intel/mediasdk ]; then \
        printf "\nexport LIBVA_DRIVER_NAME=iHD \nexport LIBVA_DRIVERS_PATH=/opt/intel/mediasdk/lib64/ \nexport GST_VAAPI_ALL_DRIVERS=1 \nexport LIBRARY_PATH=/opt/intel/mediasdk/lib64/:\$LIBRARY_PATH \nexport LD_LIBRARY_PATH=/opt/intel/mediasdk/lib64/:\$LD_LIBRARY_PATH \n" >> /home/openvino/.bashrc; \
        printf "\nexport LIBVA_DRIVER_NAME=iHD \nexport LIBVA_DRIVERS_PATH=/opt/intel/mediasdk/lib64/ \nexport GST_VAAPI_ALL_DRIVERS=1 \nexport LIBRARY_PATH=/opt/intel/mediasdk/lib64/:\$LIBRARY_PATH \nexport LD_LIBRARY_PATH=/opt/intel/mediasdk/lib64/:\$LD_LIBRARY_PATH \n" >> /root/.bashrc; \
    fi;


RUN apt-get update && \
    apt-get autoremove -y dpkg-dev && \
    rm -rf /var/lib/apt/lists/*


USER openvino
WORKDIR ${INTEL_OPENVINO_DIR}

COPY smartcity_demo.sh /home/openvino
COPY run_command.py /home/openvino
COPY benchmark_models_cmds.txt /home/openvino
COPY bonus_demo_w_counting.sh /home/openvino
COPY benchmark_test_rich.txt /home/openvino

CMD ["/bin/bash"]

# Setup custom layers below

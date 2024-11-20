# Dockerfile has following arguments: image, tag
# image - base image (default: tensorflow/tensorflow)
# tag - tag for Tensorflow Image (default: 2.10.0)
# If you need to change default values, during the build do:
# docker build -t ai4oshub/ai4os-dev-env --build-arg tag=XX .

ARG image=ubuntu
ARG tag=22.04
# Base image, e.g. tensorflow/tensorflow:2.10.0
FROM ${image}:${tag}

LABEL maintainer='V.Kozlov (KIT)'

# Install ubuntu updates, some tools
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        mc \
        nano && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Set LANG environment
ENV LANG=C.UTF-8

# Set the working directory
WORKDIR /srv

# Open DEEPaaS port, Monitoring port, IDE port
EXPOSE 5000 6006 8888

# Run the container forever
CMD ["sleep", "infinity"] 
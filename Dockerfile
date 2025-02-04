# Dockerfile
FROM ubuntu:20.04

# Prevent interactive prompts during build
ARG DEBIAN_FRONTEND=noninteractive

# Install Python and sudo
RUN apt-get update && \
    apt-get install -y python3 sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM registry.cn-hangzhou.aliyuncs.com/acs/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    openssh-client \
    autossh \
    sshpass \
    curl \
    expect \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

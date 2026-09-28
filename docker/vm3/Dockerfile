FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    sudo \
    curl \
    git \
    nginx \
    python3 \
    python3-pip \
    iptables \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd

RUN useradd -m -s /bin/bash devops && \
    usermod -aG sudo devops

RUN echo "devops ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devops && \
    chmod 440 /etc/sudoers.d/devops

RUN mkdir -p /home/devops/.ssh && \
    chmod 700 /home/devops/.ssh && \
    chown -R devops:devops /home/devops/.ssh

RUN sed -i \
    -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
    /etc/ssh/sshd_config

EXPOSE 22 80


COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]

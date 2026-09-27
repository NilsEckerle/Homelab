FROM debian:13-slim

ARG K3D_VERSION=v5.8.3
# check https://pkgs.k8s.io for the current stable minor
ARG K8S_MINOR=v1.34

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg iptables iproute2 uidmap \
      e2fsprogs xfsprogs kmod procps git \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" > /etc/apt/sources.list.d/docker.list \
 && curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" -o /tmp/k8s.key \
 && gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg /tmp/k8s.key \
 && rm /tmp/k8s.key \
 && chmod a+r /etc/apt/keyrings/kubernetes.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update && apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
      kubectl \
 && rm -rf /var/lib/apt/lists/*

# k3d, pinned binary rather than curl|bash
RUN curl -fsSLo /usr/local/bin/k3d "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-$(dpkg --print-architecture)" \
 && chmod +x /usr/local/bin/k3d \
 && k3d version

VOLUME /var/lib/docker

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]

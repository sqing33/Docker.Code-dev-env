# Dockerfile
FROM continuumio/miniconda3

WORKDIR /app

# 安装必要的工具、Node.js、C/C++编译工具，OpenSSH-server，并清理apt缓存
RUN apt-get update && apt-get install -y \
  curl \
  openssh-server \
  sudo \
  build-essential \ 
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

# Go 安装，设置最新的稳定版本
ARG GO_VERSION=1.25.0 # 
RUN curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
  tar -C /usr/local -xzf /tmp/go.tar.gz && \
  rm /tmp/go.tar.gz

# 设置Go环境变量
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/app" 
RUN mkdir -p ${GOPATH}/bin ${GOPATH}/src


# SSH服务器配置
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
  mkdir -p /run/sshd


# 设置 Conda 环境和 pip 镜像源，将 conda 环境和依赖安装位置设置为 /app/conda_envs
RUN mkdir -p /app/conda_envs && \
  echo 'envs_dirs:' >> /root/.condarc && \
  echo '  - /app/conda_envs' >> /root/.condarc && \
  echo 'pkgs_dirs:' >> /root/.condarc && \
  echo '  - /app/conda_envs/pkgs' >> /root/.condarc && \
  pip config set global.index-url https://mirrors.huaweicloud.com/repository/pypi/simple && \
  pip config set install.trusted-host mirrors.huaweicloud.com

# 安装 pnpm ，设置镜像源，将 pnpm 缓存位置设置为/app/pnpm_store
RUN npm install -g pnpm && \
  mkdir -p /app/pnpm_store && \
  pnpm config set store-dir /app/pnpm_store && \
  npm config set registry https://mirrors.huaweicloud.com/repository/npm/ && \
  pnpm config set registry https://mirrors.huaweicloud.com/repository/npm/

# 安装 code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 18822
EXPOSE 18888

CMD ["/usr/local/bin/entrypoint.sh"]

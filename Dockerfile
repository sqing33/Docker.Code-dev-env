# Stage 0: Builder (Go installation)
# 使用 Debian 作为 Go 编译环境的基础镜像
FROM debian:bookworm-slim as builder

WORKDIR /app

# 安装必要的系统工具、Go编译依赖和证书
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        tar \
        build-essential \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/*

# Go 安装：设置最新的稳定版本并安装
ARG GO_VERSION=1.25.0
RUN curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# ----------------------------------------------------------------
# Stage 1: Final Image (基于 Debian 的 Python 环境)
# ----------------------------------------------------------------
# 切换到基于 Debian 的 Python 最小化镜像，兼容性更好
FROM python:3.12-slim-bookworm as stage-1

WORKDIR /app

# 1. 安装 Debian 运行时依赖
# 安装 openssh-server, sudo, curl, zsh, git, fzf 等开发工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        curl \
        zsh \
        git \
        fzf \
        procps \
        && rm -rf /var/lib/apt/lists/*

# 安装 Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs

# 设置 root 用户的默认 shell 为 Zsh
RUN chsh -s /bin/zsh root

# 2. 安装 uv 和 Node.js 全局工具
RUN pip install uv && \
    npm install -g pnpm && \
    npm install -g @anthropic-ai/claude-code && \
    npm install -g @musistudio/claude-code-router

# 3. 设置 pnpm 缓存目录
RUN mkdir -p /app/pnpm_store && \
    pnpm config set store-dir /app/pnpm_store

# 4. SSH 服务器配置
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config && \
    echo 'Port 18822' >> /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    mkdir -p /run/sshd

# 5. 配置 Zsh (Oh My Zsh, 插件)
ENV ZSH_CUSTOM /root/.oh-my-zsh/custom/
# 1) 安装 Oh My Zsh
RUN curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install_omz.sh && \
    sh /tmp/install_omz.sh --unattended && \
    rm /tmp/install_omz.sh
# 2) 安装 zsh-autosuggestions 插件
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
# 3) 安装 zsh-syntax-highlighting 插件
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting

# 6. 创建 .zshrc 配置
RUN echo '# Path to your oh-my-zsh installation.' > /root/.zshrc && \
    echo 'export ZSH="/root/.oh-my-zsh"' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Set name of the theme to load' >> /root/.zshrc && \
    echo 'ZSH_THEME="robbyrussell"' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Zsh Plugins (fzf 已从此列表移除)' >> /root/.zshrc && \
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo 'source $ZSH/oh-my-zsh.sh' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# fzf shell integration (官方推荐方式)' >> /root/.zshrc && \
    echo 'source <(fzf --zsh)' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Go Environment Variables' >> /root/.zshrc && \
    echo 'export PATH="/usr/local/go/bin:${PATH}"' >> /root/.zshrc && \
    echo 'export GOPATH="/app"' >> /root/.zshrc

# 7. 复制 Go 环境和 entrypoint 脚本
COPY --from=builder /usr/local/go /usr/local/go
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 设置 Go 环境变量 (为非 Zsh 场景保留)
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/app"
RUN mkdir -p ${GOPATH}/bin ${GOPATH}/src

EXPOSE 18822

CMD ["/usr/local/bin/entrypoint.sh"]

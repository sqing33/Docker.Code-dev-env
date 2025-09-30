# === Stage 1: builder (构建阶段 - 仅用于 Go 环境的安装) ===
# 使用 debian:stable-slim 作为更轻量的 Go 编译环境，因为我们不再在这一阶段安装 Node.js 工具
FROM debian:bookworm-slim AS builder

WORKDIR /app

# 1. 安装 Go 编译所需的系统工具和依赖
# **重要修复:** 添加 ca-certificates 解决 curl SSL 错误 (exit code 77)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        tar \
        build-essential \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. Go 安装 (在 builder 阶段完成，最终产物将被复制)
ARG GO_VERSION=1.25.0 
RUN curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# 设置Go环境变量和目录
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/app" 
RUN mkdir -p ${GOPATH}/bin ${GOPATH}/src


# === Stage 2: final (最终运行时阶段 - 使用 Python 3.12 Alpine) ===
# 终极最小化基础镜像
FROM python:3.12-alpine

WORKDIR /app

# 1. 安装 Alpine 上的运行时依赖
# 添加 nodejs, npm, zsh, git, fzf, shadow (用于 chsh 命令)
RUN apk add --no-cache \
    openssh-server \
    sudo \
    curl \
    nodejs \
    npm \
    zsh \
    git \
    fzf \
    shadow # <-- **新增 shadow 包，修复 chsh 错误**

# 设置 root 用户的默认 shell 为 Zsh
RUN chsh -s /bin/zsh root

# 2. 安装 uv 
RUN pip install uv

# 3. 从 builder 阶段复制 Go 运行时
COPY --from=builder /usr/local/go /usr/local/go
COPY --from=builder /app/bin /app/bin

# 4. pnpm 配置和安装
RUN npm install -g pnpm && \
    mkdir -p /app/pnpm_store && \
    pnpm config set store-dir /app/pnpm_store && \
    npm config set registry https://mirrors.huaweicloud.com/repository/npm/ && \
    pnpm config set registry https://mirrors.huaweicloud.com/repository/npm/

# 5. 安装 Claude Code Tools
RUN npm install -g @anthropic-ai/claude-code @musistudio/claude-code-router

# 6. Zsh 配置 (Oh My Zsh 和插件)
COPY install_zsh_config.sh /tmp/install_zsh_config.sh
RUN sh /tmp/install_zsh_config.sh

# 重新设置Go环境变量，并更新 PATH 确保复制的 Go 命令可用
ENV PATH="/usr/local/go/bin:/usr/local/bin:${PATH}"
ENV GOPATH="/app" 
RUN mkdir -p ${GOPATH}/bin ${GOPATH}/src

# SSH服务器配置
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'Port 18822' >> /etc/ssh/sshd_config && \
    mkdir -p /run/sshd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 18822

CMD ["/usr/local/bin/entrypoint.sh"]

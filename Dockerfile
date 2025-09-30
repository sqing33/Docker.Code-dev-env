# Stage 0: Builder (使用 Debian 基础镜像处理 Go 编译和证书)
# ----------------------------------------------------------------
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
# Stage 1: Final Image (基于 Python 3.12 Alpine 的最小化运行时环境)
# ----------------------------------------------------------------
FROM python:3.12-alpine as stage-1

WORKDIR /app

# 1. 安装 Alpine 上的运行时依赖
# 安装 openssh-server, sudo, curl, nodejs, npm, zsh, git, fzf, shadow, bash
RUN apk add --no-cache \
    openssh-server \
    sudo \
    curl \
    nodejs \
    npm \
    zsh \
    git \
    fzf \
    shadow \
    bash \
    && rm -rf /var/cache/apk/*

# 设置 root 用户的默认 shell 为 Zsh
RUN chsh -s /bin/zsh root

# 2. 安装 uv 和 Node.js 全局工具
RUN pip install uv && \
    npm install -g pnpm && \
    npm install -g @anthropic-ai/claude-code && \
    npm install -g @musistudio/claude-code-router

# 3. 设置 pnpm 缓存目录（必须在 root 用户下创建）
RUN mkdir -p /app/pnpm_store && \
    pnpm config set store-dir /app/pnpm_store

# 4. SSH服务器配置 (最终修复: 确保 TCP 转发生效)
# 复制默认配置到一个临时文件
RUN cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig && \
    # 替换或添加我们需要的配置
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    # 确保 AllowTcpForwarding 存在并设置为 yes
    echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config && \
    echo 'Port 18822' >> /etc/ssh/sshd_config && \
    # 创建必要的运行目录
    mkdir -p /run/sshd

# 5. 配置 Zsh (Oh My Zsh, P10k 主题, 插件)
# Zsh 插件目录
ENV ZSH_CUSTOM /root/.oh-my-zsh/custom/
# 1) 安装 Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    # 2) 安装 Powerlevel10k 主题 (通过 git clone)
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k && \
    # 3) 安装 zsh-autosuggestions 插件
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions && \
    # 4) 安装 zsh-syntax-highlighting 插件
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting

# 6. 创建 .zshrc 配置 (启用插件和主题)
RUN echo '# Zsh 配置' > /root/.zshrc && \
    echo 'ZSH="/root/.oh-my-zsh"' >> /root/.zshrc && \
    echo 'POWERLEVEL9K_INSTANT_PROMPT=quiet' >> /root/.zshrc && \
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> /root/.zshrc && \
    echo 'plugins=(git fzf zsh-autosuggestions zsh-syntax-highlighting)' >> /root/.zshrc && \
    echo 'source $ZSH/oh-my-zsh.sh' >> /root/.zshrc && \
    # 确保 fzf 的 key bindings 生效
    echo '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh' >> /root/.zshrc

# 7. 复制 Go 环境和 entrypoint 脚本
# 从 builder 阶段复制 Go 编译后的环境
COPY --from=builder /usr/local/go /usr/local/go
# 复制 entrypoint.sh 并设置权限
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 设置 Go 环境变量 (供非交互式 Shell 和 CMD 使用)
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/app"
RUN mkdir -p ${GOPATH}/bin ${GOPATH}/src

EXPOSE 18822

CMD ["/usr/local/bin/entrypoint.sh"]

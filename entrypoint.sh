#!/bin/bash

# ==========================================================
# 检查并生成 SSH Host Keys
# ----------------------------------------------------------
# 如果 /etc/ssh/ 目录下没有主机密钥，sshd 会退出。
# 必须先生成这些密钥才能启动服务。
# ==========================================================

HOSTKEY_RSA="/etc/ssh/ssh_host_rsa_key"

if [ ! -f "$HOSTKEY_RSA" ]; then
    echo "SSH host keys not found. Generating new keys..."
    # 确保 sshd 启动所需的目录权限正确
    ssh-keygen -A # 自动生成所有标准密钥类型 (RSA, ECDSA, ED25519)
    echo "SSH host keys generated successfully."
else
    echo "SSH host keys found. Skipping generation."
fi

# ==========================================================
# 启动配置
# ==========================================================

# 设置Go环境变量，确保它们对通过entrypoint启动的sshd子进程可见
export PATH="/usr/local/go/bin:${PATH}"
export GOPATH="/app"
echo "Go environment variables (PATH, GOPATH) configured."


# 如果ROOT_PASSWORD环境变量存在，则设置root用户的密码
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "Root password has been set."
else
    echo "Warning: ROOT_PASSWORD environment variable not set. Root login might require SSH keys or be disabled."
fi

# 启动SSH服务
echo "Starting SSH service on port 18822..."
# -D: 不作为守护进程运行
# -e: 强制sshd将日志发送到stderr，以便Docker捕获
/usr/sbin/sshd -D -e &

# 等待后台进程(sshd)结束，保持容器运行
# 这使得sshd成为容器的主要服务，其输出被正确捕获为日志
echo "Keeping container alive..."
wait

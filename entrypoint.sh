#!/bin/bash
set -e

# --- SSH Host Key 生成 ---
# 检查是否存在 SSH 主机密钥，如果不存在则生成
if [ -f "/etc/ssh/ssh_host_rsa_key" ]; then
    echo "SSH host keys found. Skipping generation."
else
    echo "SSH host keys not found. Generating new keys..."
    # 生成主机密钥 (使用 Debian 命令)
    /usr/sbin/ssh-keygen -A
    echo "SSH host keys generated successfully."
fi

# --- 环境设置 ---
echo "Go environment variables (PATH, GOPATH) configured."

# --- 密码设置 (修复: 读取环境变量) ---
# 检查环境变量 ROOT_PASSWORD 是否设置
CONTAINER_PASSWORD="${ROOT_PASSWORD:-rootpassword}"

# 为 root 用户设置密码
echo "root:${CONTAINER_PASSWORD}" | chpasswd
echo "Root password has been set."

# --- 启动 SSH 服务 ---
echo "Starting SSH service on port 18822..."
# 使用 -D 标志在前台运行 SSHD，并指定端口
/usr/sbin/sshd -D -p 18822 &

# --- 保持容器存活 ---
echo "Keeping container alive..."
# 等待后台进程（sshd）结束，从而保持容器运行
wait

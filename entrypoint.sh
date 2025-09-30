#!/bin/bash

# ==========================================================
# 1. 显式设置 Go 环境变量
# ==========================================================
export PATH="/usr/local/go/bin:/usr/local/bin:$PATH"
export GOPATH="/app"
echo "Go environment variables (PATH, GOPATH) configured."

# ==========================================================
# 2. 设置 root 用户的密码
# ==========================================================
if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
  echo "Root password has been set."
else
  echo "Warning: ROOT_PASSWORD environment variable not set. Root login might require SSH keys or be disabled."
fi

# ==========================================================
# 3. 启动 SSH 服务
# ==========================================================
echo "Starting SSH service on port 18822..."
/usr/sbin/sshd -D &

# ==========================================================
# 4. 保持容器持续运行
# ==========================================================
echo "Keeping container alive..."
tail -f /dev/null

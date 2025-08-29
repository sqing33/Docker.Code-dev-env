#!/bin/bash

# 如果ROOT_PASSWORD环境变量存在，则设置root用户的密码
if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
  echo "Root password has been set."
else
  echo "Warning: ROOT_PASSWORD environment variable not set. Root login might require SSH keys or be disabled."
fi

# 启动SSH服务
/usr/sbin/sshd -D &

# 启动 code-server
exec code-server --bind-addr 0.0.0.0:18888 --auth none /app

#!/bin/sh

# Zsh 配置文件安装脚本，用于 root 用户

OHMYZSH_DIR="/root/.oh-my-zsh"
ZSHRC_FILE="/root/.zshrc"
PLUGINS_DIR="${OHMYZSH_DIR}/custom/plugins"
THEME_DIR="${OHMYZSH_DIR}/custom/themes"

# 1. 安装 Oh My Zsh (OMZ)
# 使用 git 克隆代替官方安装脚本，以避免交互式提示
echo "Installing Oh My Zsh..."
git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git ${OHMYZSH_DIR} || { echo "OMZ failed to clone"; exit 1; }

# 2. 安装 zsh-autosuggestions
echo "Installing zsh-autosuggestions..."
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${PLUGINS_DIR}/zsh-autosuggestions || { echo "Autosuggestions failed to clone"; exit 1; }

# 3. 安装 zsh-syntax-highlighting
echo "Installing zsh-syntax-highlighting..."
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${PLUGINS_DIR}/zsh-syntax-highlighting || { echo "Syntax Highlighting failed to clone"; exit 1; }

# 4. 安装 Powerlevel10k 主题
echo "Installing Powerlevel10k theme..."
git clone --depth 1 https://github.com/romkatv/powerlevel10k.git ${THEME_DIR}/powerlevel10k || { echo "Powerlevel10k failed to clone"; exit 1; }

# 5. 创建或替换 .zshrc 文件
echo "Creating custom .zshrc for root user..."

# 注意：Powerlevel10k 主题的最佳配置通常放在 .p10k.zsh 中，这里只做基础配置
cat > ${ZSHRC_FILE} << 'EOF'
# This file is managed by the Dockerfile build process.

# Path to your oh-my-zsh installation.
export ZSH="${HOME}/.oh-my-zsh"

# Set name of the theme to load --- Powerlevel10k is recommended
ZSH_THEME="powerlevel10k/powerlevel10k"

# Zsh Plugins
# 推荐加载 git (OMZ 内建), zsh-autosuggestions, zsh-syntax-highlighting
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Recommended: Enable fzf key bindings and fuzzy completion
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# Custom configurations
# 容器内使用 UTF-8
export LANG='en_US.UTF-8'
export LANGUAGE='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# Go Environment variables (Optional, but good practice here too)
# 虽然在 entrypoint.sh 中已设置，但这里再次设置可确保所有 Zsh 启动方式都生效
export PATH="/usr/local/go/bin:/usr/local/bin:$PATH"
export GOPATH="/app"

# Powerlevel10k config placeholder
# 在第一次 SSH 登录时，用户需要手动运行 p10k configure 来创建 ~/.p10k.zsh 文件。
if [[ -f ~/.p10k.zsh ]]; then
  source ~/.p10k.zsh
fi
EOF

echo "Zsh configuration complete. User 'root' will use Zsh with plugins."

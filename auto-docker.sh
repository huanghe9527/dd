#!/bin/bash
# 遇到错误时退出脚本
set -e

# 更新软件包索引并安装必要依赖
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# 创建密钥环目录
sudo install -m 0755 -d /etc/apt/keyrings

# 添加 Docker 官方 GPG 密钥，若文件已存在则自动覆盖
if [ -f /etc/apt/keyrings/docker.gpg ]; then
    echo "GPG 密钥文件已存在，正在覆盖..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
else
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 添加 Docker 官方仓库到 APT 源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 再次更新软件包索引
sudo apt-get update

# 安装所有关键 Docker 组件
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-scan-plugin

# 启动并启用 Docker 服务
sudo systemctl enable docker
sudo systemctl start docker

# 验证安装结果
echo "Docker 安装完成。已安装的版本："
docker --version
docker compose version
docker buildx version
containerd --version

# 将当前用户添加到 docker 组（可选，允许非 root 用户运行 Docker）
echo "将当前用户添加到 docker 组..."
sudo usermod -aG docker $USER
echo "请注销并重新登录以应用 docker 组权限变更。"

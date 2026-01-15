#!/bin/bash

set -e

# 检查必要的环境变量
if [ -z "${BASTION_HOST}" ] || [ -z "${TUNNEL_CONFIG}" ]; then
    echo "错误: 必须设置 BASTION_HOST 和 TUNNEL_CONFIG 环境变量"
    exit 1
fi

# 检查认证方式：密码或SSH密钥
if [ -z "${SSH_PASSWORD}" ] && [ ! -f /root/.ssh/id_rsa ]; then
    echo "错误: 需要提供认证方式之一："
    echo "  1. 设置 SSH_PASSWORD 环境变量（密码认证）"
    echo "  2. 将SSH私钥放到 ssh_key/id_rsa（密钥认证）"
    exit 1
fi

# 设置 SSH 用户（默认为 deploy）
SSH_USER=${SSH_USER:-deploy}

echo "=== SSH 隧道调试信息 ==="
echo "跳板机: ${SSH_USER}@${BASTION_HOST}"
echo "隧道配置: ${TUNNEL_CONFIG}"

# 确保 .ssh 目录存在并设置正确权限
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 设置SSH配置文件权限
if [ -f /root/.ssh/config ]; then
    chown root:root /root/.ssh/config
    chmod 600 /root/.ssh/config
fi

# 确保 known_hosts 文件存在并设置正确权限
if [ ! -f /root/.ssh/known_hosts ]; then
    touch /root/.ssh/known_hosts
fi
chown root:root /root/.ssh/known_hosts
chmod 600 /root/.ssh/known_hosts

# 设置整个.ssh目录的所有权
chown -R root:root /root/.ssh

# 添加目标主机到 known_hosts（避免首次连接时的交互提示）
echo "扫描主机密钥..."
ssh-keyscan -p "${SSH_PORT}" -H "${BASTION_HOST}" >> /root/.ssh/known_hosts 2>/dev/null || echo "警告: 无法扫描主机密钥"

# 测试网络连通性（ping可能被防火墙阻止，但SSH仍可工作）
echo "测试网络连通性..."
if ping -c 1 -W 2 "${BASTION_HOST}" &> /dev/null; then
    echo "网络连通性: PING正常"
else
    echo "网络连通性: PING失败到 ${BASTION_HOST}（这很正常，许多服务器禁用PING）"
    echo "继续尝试SSH连接..."
fi

# 构建 SSH 命令 - 绑定到所有接口以便Docker端口映射工作
SSH_CMD="autossh -M 0 -N -v -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o GatewayPorts=yes -p ${SSH_PORT}"

# 添加多个端口转发
# 去除配置中的所有空格（支持多行格式）
CLEAN_CONFIG="${TUNNEL_CONFIG// /}"
IFS=',' read -ra TUNNELS <<< "${CLEAN_CONFIG}"
for tunnel in "${TUNNELS[@]}"; do
    IFS=':' read -ra PARTS <<< "${tunnel}"
    if [ ${#PARTS[@]} -eq 3 ]; then
        LOCAL_PORT=${PARTS[0]}
        TARGET_HOST=${PARTS[1]}
        TARGET_PORT=${PARTS[2]}
        SSH_CMD="$SSH_CMD -L 0.0.0.0:${LOCAL_PORT}:${TARGET_HOST}:${TARGET_PORT}"
        echo "配置隧道: 本地 ${LOCAL_PORT} -> ${TARGET_HOST}:${TARGET_PORT}"
    fi
done

# 添加 SSH 连接信息
SSH_CMD="$SSH_CMD ${SSH_USER}@${BASTION_HOST}"

echo "启动 SSH 隧道..."
echo "执行命令: sshpass -p [密码已隐藏] $SSH_CMD"
echo ""
echo "SSH配置文件权限检查:"
ls -la /root/.ssh/

# 执行 SSH 连接
if [ -n "${SSH_PASSWORD}" ]; then
    echo "使用密码认证..."
    exec sshpass -p "${SSH_PASSWORD}" $SSH_CMD
elif [ -f /root/.ssh/id_rsa ]; then
    echo "使用SSH密钥认证..."
    exec $SSH_CMD
else
    echo "错误: 没有提供密码或SSH密钥"
    echo "请设置SSH_PASSWORD环境变量或将私钥放到ssh_key/id_rsa"
    exit 1
fi
    echo "请设置SSH_PASSWORD环境变量或将私钥放到ssh_key/id_rsa"
    exit 1
fi

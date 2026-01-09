# SSH多隧道Docker容器

通过堡垒机建立多个SSH隧道的Docker解决方案，支持密码和密钥认证，可将远程服务端口代理到本地，持久化运行。

## 🚀 快速开始

### 前置要求

- Docker Desktop (Windows/Mac/Linux)
- 堡垒机SSH访问权限
- PowerShell或Bash终端

### 部署方式

#### 方式1：使用预构建镜像（推荐，最快）[DokcerHub](https://hub.docker.com/r/earmo/multi-tunnel-ssh-tunnel)

**1. 拉取镜像**
```powershell
docker pull earmo/multi-tunnel-ssh-tunnel:latest
```

**2. 创建配置文件**

下载或创建 `docker-compose.yml`，将 `build: .` 替换为：
```yaml
services:
  ssh-tunnel:
    image: earmo/multi-tunnel-ssh-tunnel:latest
    # ... 其他配置
```

**3. 配置环境变量**
```powershell
cd D:\Docker\multi-tunnel
$env:SSH_HOST="192.168.31.123"
$env:SSH_USER="useraaa"
$env:SSH_PASSWORD="你的SSH密码"
```

**4. 启动服务**
```powershell
docker-compose up -d
```

#### 方式2：本地构建镜像

**1. 配置环境变量（Windows PowerShell）**

```powershell
cd D:\Docker\multi-tunnel
$env:SSH_HOST="192.168.31.123"
$env:SSH_USER="useraaa"
$env:SSH_PASSWORD="你的SSH密码"
```

**2. 启动服务（自动构建）**

```powershell
docker-compose up -d --build
```

### 验证连接

**查看日志**
```powershell
# 查看日志
docker-compose logs -f ssh-tunnel
```

**测试端口**
```powershell
# 测试端口
curl http://localhost:25672  # RabbitMQ
curl http://localhost:28848  # Nacos
```

看到以下日志表示成功：

```
debug1: Authentication succeeded (password).
debug1: Local forwarding listening on 0.0.0.0 port 25672
debug1: Local forwarding listening on 0.0.0.0 port 28848
```

## 🏗️ 系统架构

```
本地应用 → localhost:25672 → Docker容器 → 堡垒机(192.168.31.123) → 目标服务器(10.113.135.23:15672)
                  ↓                ↓                    ↓
              Docker端口映射    SSH隧道           实际服务端口
```

## 📁 项目结构

```
multi-tunnel/
├── docker-compose.yml    # Docker编排配置
├── Dockerfile            # 镜像构建文件
├── entrypoint.sh         # 容器启动脚本
├── ssh_key/              # SSH配置目录
│   ├── known_hosts      # 主机密钥缓存
│   └── id_rsa           # SSH私钥（可选）
├── .env                  # 环境变量（需创建）
└── README.md            # 本文档
```

## 🔧 配置说明

### 环境变量

| 变量名            | 必需 | 默认值 | 说明               |
| ----------------- | ---- | ------ | ------------------ |
| `SSH_HOST`      | 是   | -      | 堡垒机IP地址       |
| `SSH_USER`      | 是   | -      | SSH用户名          |
| `SSH_PASSWORD`  | 否*  | -      | SSH密码            |
| `TUNNEL_CONFIG` | 是   | -      | 隧道配置（见下方） |

\* SSH_PASSWORD 或 SSH密钥二选一

### 隧道配置格式

在 [docker-compose.yml](docker-compose.yml#L19-L29) 中配置：

```yaml
TUNNEL_CONFIG=
  本地端口1:目标IP:目标端口1,
  本地端口2:目标IP:目标端口2,
  ...
```

**示例：**

```yaml
TUNNEL_CONFIG=
  25672:10.113.135.23:15672,    # RabbitMQ
  28848:10.113.135.23:8848,     # Nacos HTTP
  3306:10.113.132.110:3306      # MySQL
```

### 端口映射

在 [docker-compose.yml](docker-compose.yml#L6-L14) 的 `ports` 段配置：

```yaml
ports:
  - "25672:25672"    # 宿主机端口:容器端口
  - "28848:28848"
```

## 🔐 认证方式

### 方式1：密码认证（快速）

```powershell
# 设置环境变量
$env:SSH_PASSWORD="你的密码"

# 启动服务
docker-compose up -d
```

### 方式2：SSH密钥认证（推荐）

```powershell
# 1. 生成密钥对
ssh-keygen -t rsa -b 4096 -f ./ssh_key/id_rsa

# 2. 上传公钥到堡垒机
type ./ssh_key/id_rsa.pub
# 将输出内容添加到堡垒机的 ~/.ssh/authorized_keys

# 3. 启动服务（无需密码）
docker-compose up -d
```

## 🧪 测试验证

### 检查容器状态

```powershell
# 查看运行状态
docker-compose ps

# 查看实时日志
docker-compose logs -f ssh-tunnel

# 查看端口映射
docker port multi-ssh-tunnel
```

### 测试隧道连通性

```powershell
# 测试各服务端口
curl http://localhost:25672
curl http://localhost:28848
curl http://localhost:29120
```

### 浏览器访问

- RabbitMQ: http://localhost:25672
- Nacos控制台: http://localhost:28849
- Snail-job: http://localhost:29120

## 🔍 故障排除

### 问题1：容器启动失败

**症状：** 容器不断重启

```powershell
# 查看详细日志
docker-compose logs ssh-tunnel
```

**常见原因：**

- ❌ 环境变量未设置：检查 `SSH_HOST`, `SSH_USER`, `SSH_PASSWORD`
- ❌ 网络连接失败：确认能访问堡垒机 `ping 192.168.31.123`
- ❌ SSH权限错误：容器会自动修复，等待重启

### 问题2：认证失败

**错误信息：** `Permission denied (publickey,password)`

**解决方案：**

```powershell
# 1. 确认密码正确
echo $env:SSH_PASSWORD

# 2. 确认用户名正确
echo $env:SSH_USER

# 3. 测试SSH连接
ssh useraaa@192.168.31.123
```

### 问题3：端口无法访问

**错误信息：** `curl: (7) Failed to connect`

**排查步骤：**

```powershell
# 1. 确认容器运行
docker-compose ps

# 2. 确认端口映射
docker port multi-ssh-tunnel

# 3. 检查本地防火墙
netsh advfirewall firewall show rule name=all | Select-String "25672"

# 4. 进入容器调试
docker exec -it multi-ssh-tunnel bash
netstat -tuln | grep 25672
```

### 问题4：Docker镜像拉取失败

**错误信息：** `failed to fetch oauth token`

**解决方案：**

```powershell
# 配置Docker镜像加速器（Docker Desktop → Settings → Docker Engine）
{
  "registry-mirrors": [
    "https://docker.mirrors.sjtug.sjtu.edu.cn",
    "https://docker.nju.edu.cn"
  ]
}
```

或者使用阿里云镜像（已在 [Dockerfile](Dockerfile#L1) 中配置）

## 🔧 常用命令

```powershell
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志（实时）
docker-compose logs -f ssh-tunnel

# 查看日志（最近100行）
docker-compose logs --tail=100 ssh-tunnel

# 重新构建并启动
docker-compose up -d --build

# 进入容器调试
docker exec -it multi-ssh-tunnel bash

# 清理所有资源
docker-compose down -v
```

## 📊 高级配置

### 多堡垒机配置

复制 `docker-compose.yml` 创建多个服务：

```yaml
services:
  ssh-tunnel-1:
    # ... 基本配置
    environment:
      - SSH_HOST=192.168.31.123
    ports:
      - "25672:25672"
  
  ssh-tunnel-2:
    # ... 基本配置  
    environment:
      - SSH_HOST=192.168.13.321
    ports:
      - "25673:25672"  # 不同的宿主机端口
```

### 资源限制

```yaml
services:
  ssh-tunnel:
    # ... 其他配置
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 128M
```

### 自定义健康检查

```yaml
healthcheck:
  test: |
    /bin/bash -c '
      pgrep -f autossh || exit 1
      curl -f http://localhost:28848 || exit 1
    '
  interval: 30s
  timeout: 10s
  retries: 3
```

## 🛡️ 安全建议

1. **使用SSH密钥认证** - 比密码更安全
2. **设置密钥密码保护** - 生成密钥时添加密码
3. **限制SSH来源IP** - 在堡垒机配置白名单
4. **定期轮换密码/密钥** - 提高安全性
5. **使用专用账户** - 不要使用root账户
6. **启用日志审计** - 定期检查访问日志

```powershell
# 生成带密码保护的密钥
ssh-keygen -t ed25519 -f ./ssh_key/id_ed25519 -N "强密码"
```

## 📚 技术细节

### SSH隧道原理

使用SSH Local Port Forwarding：

```bash
ssh -L [本地地址:]本地端口:目标主机:目标端口 用户@跳板机
```

实际执行命令：

```bash
autossh -M 0 -N -v \
  -o ServerAliveInterval=60 \
  -o ServerAliveCountMax=3 \
  -L 0.0.0.0:25672:10.113.135.23:15672 \
  useraaa@192.168.31.123
```

### 关键参数说明

| 参数                       | 说明                          |
| -------------------------- | ----------------------------- |
| `-M 0`                   | 禁用监控端口，使用SSH内置机制 |
| `-N`                     | 不执行远程命令，仅建立隧道    |
| `-v`                     | 详细模式，输出调试信息        |
| `ServerAliveInterval=60` | 每60秒发送保活包              |
| `ServerAliveCountMax=3`  | 3次失败后断开重连             |
| `GatewayPorts=yes`       | 允许远程主机连接到转发端口    |

### 自动重连机制

AutoSSH负责监控SSH连接状态，连接断开时自动重连：

```bash
# AutoSSH内置重连逻辑
while true; do
    ssh [参数]
    [ $? -eq 0 ] && sleep 600 || sleep 30
done
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

## 📞 支持

遇到问题？

1. 查看本文档的故障排除章节
2. 检查容器日志：`docker-compose logs ssh-tunnel`
3. 提交Issue到项目仓库[Github](https://github.com/Earmo/multi-tunnel-ssh-tunnel )

---

**最后更新：** 2026-01-09

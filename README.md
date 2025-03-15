# MTProto
一个简单易用的 MTProto 代理一键安装脚本，适用于 Ubuntu、Debian 和 CentOS 系统
## 功能特性

- **一键安装**：快速部署 MTProto 代理服务。
- **Docker 支持**：基于 Docker 容器化部署，隔离环境，易于管理。
- **TLS 伪装**：支持自定义 TLS 域名，增强抗封锁能力。
- **订阅链接**：自动生成 Telegram 代理订阅链接和二维码。
- **抗封锁优化**：内置流量混淆和抗封锁优化配置。
- **多系统支持**：支持 Ubuntu、Debian 和 CentOS 系统。

## 使用说明

### 1. 安装依赖

确保系统已安装 `curl` 和 `docker`。如果未安装，可以运行以下命令：

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y curl docker.io

# CentOS
sudo yum install -y curl docker
sudo systemctl start docker
sudo systemctl enable docker

### 2.运行脚本

```bash
#以root用户执行
bash <(curl -sL https://a.hgtrojan.com/6decfa1045)

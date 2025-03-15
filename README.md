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

```
### 2.运行脚本

```bash
#以root用户执行
bash <(curl -sL https://a.hgtrojan.com/6decfa1045)
```
按照提示选择操作：

1. 安装代理：安装并启动 MTProto 代理服务。

2. 更新代理：更新 Docker 镜像并重启服务。

3. 卸载代理：卸载 MTProto 代理服务。

4. 启动服务：启动已安装的代理服务。

5. 重启服务：重启代理服务。

6. 停止服务：停止代理服务。

7. 查看信息：显示代理配置信息和订阅链接。

8. 修改配置：修改代理端口和 TLS 域名。

9. 查看日志：查看容器日志。

### 3. 获取订阅链接
安装完成后，选择 7. 查看信息，脚本会显示代理的订阅链接和二维码。你可以将订阅链接导入 Telegram 客户端使用。

## 示例输出

```plaintext
=============== MTProto 代理信息 ===============
 ● 当前状态: ✔ 已安装 ✔ 运行中
 ● 服务器IP: 1.1.1.1
 ● 代理端口: 1234
 ● TLS 域名: www.alibaba.com
 ● 安全密钥: 98173b6e-26bd-43ba-a522-e013bfafae93
 ● 订阅链接: https://t.me/proxy?server=1.1.1.1&port=1234&secret=98173b6e-26bd-43ba-a522-e013bfafae93
 ● 订阅链接二维码:
    ██████████████████████████████████████
    ██████████████████████████████████████
    ██████████████████████████████████████
    ██████████████████████████████████████
    ██████████████████████████████████████
===============================================
```

### 支持与反馈

如果你遇到任何问题或有改进建议，请提交 Issue。

#!/bin/bash
# MTProto 一键安装脚本
# Author: HgTrojan

RED="\033[31m"      # 错误信息
GREEN="\033[32m"    # 成功信息
YELLOW="\033[33m"   # 警告信息
BLUE="\033[36m"     # 提示信息
PURPLE="\033[35m"   # 紫色信息
PLAIN='\033[0m'

# 图标符号
CHECK="✔"
CROSS="✗"
INFO="ℹ"

export MTG_CONFIG="${MTG_CONFIG:-$HOME/.config/mtg}"
export MTG_ENV="$MTG_CONFIG/env"
export MTG_SECRET="$MTG_CONFIG/secret"
export MTG_CONTAINER="${MTG_CONTAINER:-mtg}"
export MTG_IMAGENAME="${MTG_IMAGENAME:-nineseconds/mtg}"

DOCKER_CMD="$(command -v docker)"
OSNAME=$(hostnamectl | grep -i system | cut -d: -f2)

IP=$(curl -sL -4 ip.sb)

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        colorEcho $RED " ${CROSS} 请以 root 身份执行该脚本"
        exit 1
    fi

    res=$(which yum 2>/dev/null)
    if [[ "$?" != "0" ]]; then
        res=$(which apt 2>/dev/null)
        if [ "$?" != "0" ]; then
            colorEcho $RED " ${CROSS} 不受支持的 Linux 系统"
            exit 1
        fi
        res=$(hostnamectl | grep -i ubuntu)
        if [[ "${res}" != "" ]]; then
            OS="ubuntu"
        else
            OS="debian"
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
    else
        OS="centos"
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
    fi
    res=$(which systemctl)
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " ${CROSS} 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

status() {
    if [[ -z "$DOCKER_CMD" ]]; then
        echo 0
        return
    elif [[ ! -f $MTG_ENV ]]; then
        echo 1
        return
    fi
    port=$(grep MTG_PORT $MTG_ENV | cut -d= -f2)
    if [[ -z "$port" ]]; then
        echo 2
        return
    fi
    res=$(docker ps -f "name=$MTG_CONTAINER" --format "{{.Status}}" | grep -i "up")
    if [[ -z "$res" ]]; then
        echo 3
    else
        echo 4
    fi
}

statusText() {
    res=$(status)
    case $res in
        3) echo -e "${GREEN}${CHECK} 已安装${PLAIN} ${RED}${CROSS} 未运行${PLAIN}" ;;
        4) echo -e "${GREEN}${CHECK} 已安装${PLAIN} ${GREEN}${CHECK} 运行中${PLAIN}" ;;
        *) echo -e "${RED}${CROSS} 未安装${PLAIN}" ;;
    esac
}

getData() {
    mkdir -p $MTG_CONFIG

    while true; do
        read -p " 请输入 MTProto 端口 [100-65535]: " PORT
        if [[ "$PORT" =~ ^[0-9]+$ ]] && [[ "$PORT" -ge 100 ]] && [[ "$PORT" -le 65535 ]]; then
            break
        else
            colorEcho $RED " ${CROSS} 端口号必须在 100-65535 之间"
        fi
    done

    read -p " 请输入 TLS 伪装域名 (默认: cloudflare.com): " DOMAIN
    DOMAIN=${DOMAIN:-cloudflare.com}

    echo "MTG_IMAGENAME=$MTG_IMAGENAME" > "$MTG_ENV"
    echo "MTG_PORT=$PORT" >> "$MTG_ENV"
    echo "MTG_CONTAINER=$MTG_CONTAINER" >> "$MTG_ENV"
    echo "MTG_DOMAIN=$DOMAIN" >> "$MTG_ENV"
}

installDocker() {
    if [[ -n "$DOCKER_CMD" ]]; then
        systemctl enable --now docker 2>/dev/null || true
        selinux
        return
    fi

    colorEcho $BLUE " ${INFO} 正在安装 Docker..."

    if [[ $OS == "ubuntu" || $OS == "debian" ]]; then
        $CMD_INSTALL apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/$OS/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$OS $(lsb_release -cs) stable"
        apt-get update
        $CMD_INSTALL docker-ce docker-ce-cli containerd.io
    elif [[ $OS == "centos" ]]; then
        $CMD_INSTALL yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        $CMD_INSTALL docker-ce docker-ce-cli containerd.io
    fi

    if ! command -v docker &>/dev/null; then
        colorEcho $RED " ${CROSS} Docker 安装失败"
        exit 1
    fi

    systemctl enable --now docker
    sleep 2
    selinux
}

pullImage() {
    colorEcho $BLUE " ${INFO} 正在拉取最新镜像..."
    if ! docker pull "$MTG_IMAGENAME" >/dev/null; then
        colorEcho $RED " ${CROSS} 镜像拉取失败"
        exit 1
    fi
}

selinux() {
    if [[ -f /etc/selinux/config ]] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

firewall() {
    port=$1
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port=$port/tcp
        firewall-cmd --reload
    elif ufw status | grep -qw active; then
        ufw allow $port/tcp
    else
        iptables -I INPUT -p tcp --dport $port -j ACCEPT
    fi
}

start() {
    if [[ $(status) -lt 3 ]]; then
        colorEcho $RED " ${CROSS} 请先完成安装"
        return
    fi

    set -a; source "$MTG_ENV"; set +a

    if [[ ! -f "$MTG_SECRET" ]]; then
        colorEcho $BLUE " ${INFO} 正在生成安全密钥..."
        if ! docker run --rm "$MTG_IMAGENAME" generate-secret tls -c "$MTG_DOMAIN" > "$MTG_SECRET"; then
            colorEcho $RED " ${CROSS} 密钥生成失败"
            exit 1
        fi
    fi

    docker rm -f "$MTG_CONTAINER" >/dev/null 2>&1
    if ! docker run -d \
        --name "$MTG_CONTAINER" \
        --restart unless-stopped \
        --ulimit nofile=51200:51200 \
        -p "0.0.0.0:$MTG_PORT:3128" \
        "$MTG_IMAGENAME" run "$(cat "$MTG_SECRET")" >/dev/null; then
        colorEcho $RED " ${CROSS} 服务启动失败"
        exit 1
    fi

    sleep 2
    res=$(docker ps -f "name=$MTG_CONTAINER" --format "{{.Status}}" | grep -i "up")
    if [[ -z "$res" ]]; then
        colorEcho $RED " ${CROSS} 服务启动失败"
        exit 1
    else
        colorEcho $GREEN " ${CHECK} 服务启动成功！"
    fi
}

generateSubscriptionLink() {
    set -a; source "$MTG_ENV"; set +a
    SECRET=$(cat "$MTG_SECRET" 2>/dev/null) || SECRET="未生成"
    SUBSCRIPTION_LINK="https://t.me/proxy?server=$IP&port=$MTG_PORT&secret=$SECRET"
    echo "$SUBSCRIPTION_LINK"
}

generateQRCode() {
    SUBSCRIPTION_LINK=$(generateSubscriptionLink)
    if command -v qrencode &>/dev/null; then
        echo -e "\n${BLUE}● 订阅链接二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "$SUBSCRIPTION_LINK"
    else
        colorEcho $YELLOW " ${INFO} 未安装 qrencode，无法生成二维码。"
        colorEcho $YELLOW " 请运行以下命令安装 qrencode："
        if [[ $OS == "ubuntu" || $OS == "debian" ]]; then
            echo "sudo apt install -y qrencode"
        elif [[ $OS == "centos" ]]; then
            echo "sudo yum install -y qrencode"
        fi
    fi
}

showInfo() {
    SECRET=$(cat "$MTG_SECRET" 2>/dev/null) || SECRET="未生成"
    set -a; source "$MTG_ENV"; set +a
    SUBSCRIPTION_LINK=$(generateSubscriptionLink)

    echo -e "\n${PURPLE}=============== MTProto 代理信息 ===============${PLAIN}"
    echo -e " ${BLUE}● 当前状态:${PLAIN} $(statusText)"
    echo -e " ${BLUE}● 服务器IP:${PLAIN} ${GREEN}$IP${PLAIN}"
    echo -e " ${BLUE}● 代理端口:${PLAIN} ${GREEN}$MTG_PORT${PLAIN}"
    echo -e " ${BLUE}● TLS 域名:${PLAIN} ${GREEN}$MTG_DOMAIN${PLAIN}"
    echo -e " ${BLUE}● 安全密钥:${PLAIN} ${GREEN}$SECRET${PLAIN}"
    echo -e " ${BLUE}● 订阅链接:${PLAIN} ${GREEN}$SUBSCRIPTION_LINK${PLAIN}"
    generateQRCode
    echo -e "${PURPLE}===============================================${PLAIN}\n"
}

optimizeGFW() {
    colorEcho $BLUE " ${INFO} 正在优化抗封锁配置..."
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
    sysctl -p >/dev/null
}

install() {
    getData
    installDocker
    pullImage
    start
    firewall $MTG_PORT
    optimizeGFW
    showInfo
}

menu() {
    clear
    echo -e "${PURPLE}#===============================================#"
    echo -e "#              ${GREEN}MTProto 代理管理脚本${PLAIN}             #"
    echo -e "#                 ${YELLOW}作者: HgTrojan${PLAIN}                 #"
    echo -e "#===============================================#${PLAIN}"
    echo -e "  ${GREEN}1.${PLAIN} 安装代理"
    echo -e "  ${GREEN}2.${PLAIN} 更新代理"
    echo -e "  ${GREEN}3.${PLAIN} 卸载代理"
    echo -e "  ${BLUE}-----------------------------${PLAIN}"
    echo -e "  ${GREEN}4.${PLAIN} 启动服务"
    echo -e "  ${GREEN}5.${PLAIN} 重启服务"
    echo -e "  ${GREEN}6.${PLAIN} 停止服务"
    echo -e "  ${BLUE}-----------------------------${PLAIN}"
    echo -e "  ${GREEN}7.${PLAIN} 查看信息"
    echo -e "  ${GREEN}8.${PLAIN} 修改配置"
    echo -e "  ${GREEN}9.${PLAIN} 查看日志"
    echo -e "  ${BLUE}-----------------------------${PLAIN}"
    echo -e "  ${GREEN}0.${PLAIN} 退出脚本"
    echo -e "\n 当前状态: $(statusText)"
}

checkSystem

while true; do
    menu
    read -p " 请输入操作编号 [0-9]: " choice
    case $choice in
        1) install ;;
        2) docker pull $MTG_IMAGENAME && start ;;
        3) docker rm -f $MTG_CONTAINER && docker rmi $MTG_IMAGENAME && rm -rf $MTG_CONFIG ;;
        4) start ;;
        5) docker restart $MTG_CONTAINER ;;
        6) docker stop $MTG_CONTAINER ;;
        7) showInfo ;;
        8) getData && start ;;
        9) docker logs $MTG_CONTAINER -n 20 ;;
        0) exit 0 ;;
        *) colorEcho $RED " ${CROSS} 无效选择" ;;
    esac
    read -p " 按回车键继续..."
done

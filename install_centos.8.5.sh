#!/bin/bash

# ============================================
# Shadowsocks + BBR 自动安装脚本
# 适用于 CentOS 8.5
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认配置
SS_PORT=443
SS_PASSWORD=$(openssl rand -base64 16)
SS_METHOD="xchacha20-ietf-poly1305"
SS_OBFS="http"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

check_centos() {
    if [[ ! -f /etc/centos-release ]]; then
        log_error "此脚本仅适用于 CentOS"
        exit 1
    fi
    log_info "检测到 CentOS 系统"
}

install_dependencies() {
    log_info "安装依赖包..."
    yum -y install epel-release
    yum -y install wget curl git python3
    log_info "依赖包安装完成"
}

install_shadowsocks() {
    log_info "安装 Shadowsocks-libev..."

    # 从 EPEL Testing 或其他源获取，否则编译
    cd /tmp

    # 安装编译依赖
    yum -y install gcc make autoconf automake libtool \
        mbedtls-devel libsodium-devel libev-devel pcre-devel c-ares-devel

    # 下载源码
    SS_VER="3.3.5"
    wget -q --no-check-certificate \
        "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${SS_VER}/shadowsocks-libev-${SS_VER}.tar.gz"

    if [[ -f "shadowsocks-libev-${SS_VER}.tar.gz" ]]; then
        log_info "编译安装 shadowsocks-libev..."
        tar -xzf shadowsocks-libev-${SS_VER}.tar.gz
        cd shadowsocks-libev-${SS_VER}
        ./configure --prefix=/usr --disable-documentation
        make -j$(nproc)
        make install
        cd /tmp
        rm -rf shadowsocks-libev-${SS_VER}*
    else
        log_error "下载失败，尝试备用方案..."
        # 备用：下载静态编译的二进制
        wget -q --no-check-certificate \
            "https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${SS_VER}/shadowsocks-libev-${SS_VER}.tar.xz" || true

        # 如果都失败，尝试 Go 版本
        if ! command -v ss-server &> /dev/null; then
            log_info "安装 Go 版本 shadowsocks..."
            wget -q --no-check-certificate \
                "https://github.com/shadowsocks/go-shadowsocks2/releases/download/v0.1.5/shadowsocks2-linux-x86_64.gz"
            gunzip shadowsocks2-linux-x86_64.gz
            chmod +x shadowsocks2-linux-x86_64
            mv shadowsocks2-linux-x86_64 /usr/bin/shadowsocks2

            # 创建兼容的 ss-server 软链接
            cat > /usr/bin/ss-server <<'EOF'
#!/bin/bash
CONFIG=$1
shift
/usr/bin/shadowsocks2 -s "ss://$(grep method $CONFIG | cut -d'"' -f4):$(grep password $CONFIG | cut -d'"' -f4)@:$(grep server_port $CONFIG | cut -d':' -f2 | tr -d ',')" "$@"
EOF
            chmod +x /usr/bin/ss-server
        fi
    fi

    # 创建配置目录
    mkdir -p /etc/shadowsocks-libev

    # 生成配置文件
    cat > /etc/shadowsocks-libev/config.json <<EOF
{
    "server": "0.0.0.0",
    "server_port": ${SS_PORT},
    "password": "${SS_PASSWORD}",
    "timeout": 300,
    "method": "${SS_METHOD}",
    "fast_open": true,
    "mode": "tcp_and_udp"
}
EOF

    # 配置 systemd 服务
    cat > /etc/systemd/system/shadowsocks-libev.service <<EOF
[Unit]
Description=Shadowsocks-libev Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks-libev
    systemctl restart shadowsocks-libev

    log_info "Shadowsocks 安装完成"
    echo ""
    echo "============================================"
    echo -e "${GREEN}Shadowsocks 配置信息:${NC}"
    echo "============================================"
    echo -e "服务器端口: ${GREEN}${SS_PORT}${NC}"
    echo -e "密码:       ${GREEN}${SS_PASSWORD}${NC}"
    echo -e "加密方式:   ${GREEN}${SS_METHOD}${NC}"
    echo "============================================"
    echo ""
}

install_bbr() {
    log_info "配置 BBR 加速..."

    KERNEL_VERSION=$(uname -r)
    log_info "当前内核版本: $KERNEL_VERSION"

    # CentOS 8 内核 4.18+ 已内置 BBR
    # 检查是否已配置
    if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null; then
        log_info "BBR 已配置"
    else
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1 || true
        log_info "BBR 已启用"
    fi

    # 验证
    BBR_STATUS=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    echo -e "BBR 状态: ${GREEN}${BBR_STATUS}${NC}"
}

config_firewall() {
    log_info "关闭防火墙，放行所有端口..."

    # 停止并禁用防火墙
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true

    # 清空 iptables 规则
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true

    log_info "防火墙已关闭，所有端口已放行"
}

config_system() {
    log_info "优化系统参数..."

    # 避免重复添加
    if ! grep -q "tcp_fastopen = 3" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf <<EOF

# Shadowsocks 优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
EOF
        sysctl -p > /dev/null 2>&1 || true
    fi
    log_info "系统参数优化完成"
}

generate_clash_config() {
    log_info "生成 Clash 订阅配置..."

    # 获取公网IP
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 ip.sb 2>/dev/null || echo "YOUR_SERVER_IP")

    # 创建配置目录
    mkdir -p /var/www/clash

    # 生成 Clash YAML 配置
    cat > /var/www/clash/config.yaml <<EOF
port: 7890
socks-port: 7891
allow-lan: false
mode: Rule
log-level: info
external-controller: 127.0.0.1:9090

proxies:
  - name: "我的SS"
    type: ss
    server: ${PUBLIC_IP}
    port: ${SS_PORT}
    cipher: ${SS_METHOD}
    password: "${SS_PASSWORD}"
    udp: true

proxy-groups:
  - name: "代理"
    type: select
    proxies:
      - "我的SS"
      - DIRECT

  - name: "自动选择"
    type: url-test
    proxies:
      - "我的SS"
    url: 'http://www.gstatic.com/generate_204'
    interval: 300

rules:
  - DOMAIN-SUFFIX,google.com,代理
  - DOMAIN-SUFFIX,googleapis.com,代理
  - DOMAIN-SUFFIX,youtube.com,代理
  - DOMAIN-SUFFIX,ytimg.com,代理
  - DOMAIN-SUFFIX,github.com,代理
  - DOMAIN-SUFFIX,githubusercontent.com,代理
  - DOMAIN-SUFFIX,telegram.org,代理
  - DOMAIN-SUFFIX,t.me,代理
  - DOMAIN-KEYWORD,google,代理
  - DOMAIN-KEYWORD,youtube,代理
  - DOMAIN-KEYWORD,telegram,代理
  - GEOIP,CN,DIRECT
  - MATCH,代理
EOF

    log_info "Clash 配置生成完成"
}

start_subscription_service() {
    log_info "启动订阅服务..."

    # 使用 Python 简单 HTTP 服务
    cat > /etc/systemd/system/clash-subscription.service <<EOF
[Unit]
Description=Clash Subscription Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/clash
ExecStart=/usr/bin/python3 -m http.server 25500
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable clash-subscription
    systemctl restart clash-subscription

    log_info "订阅服务启动完成"
}

show_status() {
    # 获取服务器公网IP
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 ip.sb 2>/dev/null || echo "YOUR_SERVER_IP")

    echo ""
    echo "============================================"
    echo -e "${GREEN}✓ 安装完成!${NC}"
    echo "============================================"
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║           Clash 订阅地址 (复制到客户端)           ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "\033[42;30m http://${PUBLIC_IP}:25500/config.yaml \033[0m"
    echo ""
    echo -e "${YELLOW}>>> SS 链接 (可导入其他客户端):${NC}"
    SS_LINK="ss://$(echo -n "${SS_METHOD}:${SS_PASSWORD}" | base64)@${PUBLIC_IP}:${SS_PORT}#MySS"
    echo -e "\033[36m${SS_LINK}${NC}"
    echo ""
    echo -e "${YELLOW}>>> 连接信息:${NC}"
    echo -e "  服务器:   ${GREEN}${PUBLIC_IP}${NC}"
    echo -e "  端口:     ${GREEN}${SS_PORT}${NC}"
    echo -e "  密码:     ${GREEN}${SS_PASSWORD}${NC}"
    echo -e "  加密:     ${GREEN}${SS_METHOD}${NC}"
    echo ""
    echo -e "${YELLOW}>>> BBR 状态:${NC} ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${NC}"
    echo ""
    echo "============================================"
    echo -e "SS配置:   ${YELLOW}/etc/shadowsocks-libev/config.json${NC}"
    echo -e "Clash配置: ${YELLOW}/var/www/clash/config.yaml${NC}"
    echo -e "重启SS:   ${YELLOW}systemctl restart shadowsocks-libev${NC}"
    echo -e "重启订阅: ${YELLOW}systemctl restart clash-subscription${NC}"
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  请在云控制台安全组放行以下端口:                     ║${NC}"
    echo -e "${YELLOW}║    • ${SS_PORT}/TCP + ${SS_PORT}/UDP (SS服务端口)    ║${NC}"
    echo -e "${YELLOW}║    • 25500/TCP (订阅服务端口)                       ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
    echo "============================================"
}

main() {
    echo ""
    echo "============================================"
    echo "  Shadowsocks + BBR 自动安装脚本"
    echo "  适用于 CentOS 8.5"
    echo "============================================"
    echo ""
    echo -e "将使用以下默认配置:"
    echo -e "  端口:     ${GREEN}${SS_PORT}${NC}"
    echo -e "  密码:     ${GREEN}${SS_PASSWORD}${NC}"
    echo -e "  加密:     ${GREEN}${SS_METHOD}${NC}"
    echo ""

    read -p "按回车开始安装，或 Ctrl+C 取消..." -r
    echo ""

    check_root
    check_centos
    install_dependencies
    install_shadowsocks
    install_bbr
    generate_clash_config
    start_subscription_service
    config_firewall
    config_system
    show_status
}

main "$@"

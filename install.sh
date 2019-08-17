#/usr/bin/fish
yum -y install fish
yum -y install unzip
yum -y install git
yum -y install netdata

切换当前用户默认Shell
chsh -s /usr/bin/fish

# 1. 安装shadowsocks
    git clone https://github.com/teddysun/shadowsocks_install.git
    cd shadowsocks_install/
    git checkout -b master origin/master
    chmod 777 *.sh
    ./shadowsocks-all.sh
    #选择安装shadowsocks-libev
    #端口输入80, 其他冷门端口可能被vultr或防火墙拦截
    #开启simple-obfs, 选择http类型或者tls类型
    cd ../

# 2. 安装aria2ng
    git clone https://github.com/helloxz/ccaa.git
    chmod 777 ./ccaa/ccaa.sh
    cd ccaa
    ./ccaa.sh
    cd ../

# 3. 安装魔改BBR
    wget -N --no-check-certificate "https://raw.githubusercontent.com/dlxg/Linux-NetSpeed/master/tcp.sh"
    chmod +x tcp.sh
    ./tcp.sh
    #先选0升级，再安装

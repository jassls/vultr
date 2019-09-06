#!/usr/bin/bash

#关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service

#安装软件包
yum -y install fish
yum -y install vim
yum -y install unzip
yum -y install git
yum -y install netdata
yum -y install vsftpd


#切换当前用户默认Shell
chsh -s /usr/bin/fish

#修改配置文件
NETDATABIND=`grep "bind to" /etc/netdata/netdata.conf`


echo "${NETDATABIND}"
if [[ $NETDATABIND =~ "localhost" ]]; then
   echo -e "\n\nnetdata listen bind with localhost, it should be a public IP address"
   echo -e "Please change IP in /etc/netdata/netdata.conf"
   echo -e "Exit..."
   exit -1
fi

#启动服务
systemctl restart netdata

#设置开机自动启动
systemctl enable netdata


# 1. 安装shadowsocks
    git clone https://github.com/teddysun/shadowsocks_install.git
    cd shadowsocks_install/
    git checkout -b master origin/master
    chmod 777 *.sh
    ./shadowsocks-all.sh
    #选择安装shadowsocks-libev
    #端口输入80, 其他冷门端口可能被vultr或防火墙拦截
    #加密算法选择xchacha20-ietf-poly1305
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
    echo "按照以下顺序输入:"
    echo "   0. 升级脚本"
    echo "   1. 安装 BBR/BBR魔改版内核"
    echo "   6. 使用暴力BBR魔改版加速\(不支持部分系统\)"

    read variable

    ./tcp.sh
    
# 4. 配置ftp服务
    # 开启SSL
    cd /etc/pki/tls/certs
    make vsftpd.pem
    cp -a vsftpd.pem /etc/vsftpd/
    echo "ssl_enable=YES" >> /etc/vsftpd/vsftpd.conf
    echo "allow_anon_ssl=YES" >> /etc/vsftpd/vsftpd.conf
    echo "force_anon_data_ssl=YES" >> /etc/vsftpd/vsftpd.conf
    echo "force_anon_logins_ssl=YES" >> /etc/vsftpd/vsftpd.conf
    echo "force_local_data_ssl=YES" >> /etc/vsftpd/vsftpd.conf
    echo "force_local_logins_ssl=YES" >> /etc/vsftpd/vsftpd.conf
    echo "ssl_tlsv1=YES" >> /etc/vsftpd/vsftpd.conf
    echo "rsa_cert_file=/etc/vsftpd/vsftpd.pem" >> /etc/vsftpd/vsftpd.conf
    cd ..




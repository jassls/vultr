#!/usr/bin/bash

tools(){
	echo "Start install tools"
	#安装软件包
	yum -y install fish
	yum -y install vim
	yum -y install unzip
	yum -y install git
	yum -y install netdata
	yum -y install vsftpd
	yum -y install iperf3
        yum -y install psmisc 

	#切换当前用户默认Shell
	chsh -s /usr/bin/fish

	#修改配置文件
	NETDATABIND=`grep "bind to" /etc/netdata/netdata.conf`

	echo "${NETDATABIND}"
	if [[ $NETDATABIND =~ "localhost" ]]; then
   		echo -e "\n\nnetdata listen bind with localhost, it should be a public IP address"
   		echo -e "Please change domain name in /etc/netdata/netdata.conf"
   		echo -e "Exit..."
   		exit -1
	fi

	#启动服务
	systemctl restart netdata

	#设置开机自动启动
	systemctl enable netdata

	# 配置ftp服务
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

	#关闭防火墙
	systemctl stop firewalld.service
	systemctl disable firewalld.service
}

shadowsocks() {
	echo "Start install shadowsocks"
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
        systemctl enable shadowsocks-libev
}

aria2(){
	echo "Start install aria2"
	systemctl start firewalld.service

	# 2. 安装aria2ng
	git clone https://github.com/helloxz/ccaa.git
	chmod 777 ./ccaa/ccaa.sh
	cd ccaa
	./ccaa.sh
	cd ../
	systemctl stop firewalld.service
}

bbr(){
	echo "Start install BBR"
	# 3. 安装魔改BBR
	wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"
	echo "按照以下顺序执行:(注意, 只用BBRplus即可，效果最好。(也不要用锐速，多倍发包)"
	echo "   升级脚本"
	echo "   内核管理选择: 安装 BBRplus版内核"
	echo "   加速管理选择: 使用BBRplus版加速"
	echo "   杂项管理选择: 系统配置优化"

	read variable

	chmod +x tcp.sh
	./tcp.sh
}

restartallservice() {
        # 重启Shadowsocks
        systemctl restart shadowsocks-libev

        #重启aria2
        killall -9 aria2c
	nohup aria2c --conf-path=/etc/ccaa/aria2.conf &	

        #重启netdata
	systemctl restart netdata
}

bye() {
	exit 0
}

echo "Please select your function"

menu="tools shadowsocks aria2 bbr restartallservice bye"

select menu in $menu:
do 
    case $REPLY in
    1) tools
    ;;
    2) shadowsocks
    ;;
    3) aria2
    ;;
    4) bbr
    ;;
    5) restartallservice
    ;;
    6) bye
    ;;
    *) echo "please choose 1-6"
    ;;
    esac
done

    




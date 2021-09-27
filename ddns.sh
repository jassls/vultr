#!/bin/bash

#通过https://console.dnspod.cn/account/token/token获得
#格式为ID,TOKEN, 如261078,xxxxxxxxxxxxxxxxxxxxxxxxxxx
login_token=261078,xxxxxxxxxxxxxxxxxxxx

domain=jassls.com

#通过curl -X POST https://dnsapi.cn/Record.List -d 'login_token=261078,xxxxxxxxxxxxxxxxxxxx&format=json&domain=jassls.com'可以查询到
record_id=918796226

sub_domain=ssr

myip=`ping ${sub_domain}.${domain} -c 1 -w 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
echo "当前ip:$myip"

newip=`curl ifconfig.me`
echo "最新ip:$newip"


if [ "$myip" = "$newip" ]; then
    echo "当前IP与正在解析的IP相同，不更新"
else
    echo "当前IP与正在解析的IP不同，更新"
    result=$(curl -s -X POST https://dnsapi.cn/Record.Ddns -d 'login_token=$login_token&format=json&domain=$domain&record_id=$record_id&sub_domain=$sub_domain&value=$newip&record_type=A&record_line=默认')
    grepResult=$(echo $result | grep "\"code\":\"1\"")
    if [[ "$grepResult" != "" ]]
    then
       echo '更新成功'
    else
       echo '更新失败'
    fi
fi

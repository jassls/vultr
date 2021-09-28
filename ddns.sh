#!/bin/sh
login_token=261078,xxxxxxxxxxxxxxxxxxxxxxxxxxxx
domain=jassls.com
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
    result=$(curl -s -d "login_token=$login_token&format=json&domain=$domain&record_id=$record_id&sub_domain=$sub_domain&value=$newip&record_type=A&record_line=默认" https://dnsapi.cn/Record.Ddns)
    grepResult=$(echo $result | grep "\"code\":\"1\"")
    if [[ "$grepResult" != "" ]]
    then
       echo '更新成功'
    else
       echo '更新失败'
    fi
fi

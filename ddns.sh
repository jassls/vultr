#!/bin/bash

#通过https://console.dnspod.cn/account/token/token获得
#格式为ID,TOKEN, 如261078,xxxxxxxxxxxxxxxxxxxxxxxxxxx
LOGIN_TOKEN=""

#通过curl -X POST https://dnsapi.cn/Record.List -d 'login_token=261078,xxxxxxxxxxxxxxxxxxxx&format=json&domain=jassls.com'可以查询到
RECORD_ID=""

#指向的新的地址
NEW_IP="1.1.1.1"
curl -X POST https://dnsapi.cn/Record.Ddns -d 'login_token=${LOGIN_TOKEN}&format=json&domain=jassls.com&record_id=${RECORD_ID}&record_line=默认&sub_domain=ssr&value=${NEW_IP}'

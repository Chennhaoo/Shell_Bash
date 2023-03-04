#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: 三网回程详细测试
#	Version: 2023.03.05_01
#	Author: ChennHaoo
#   参考：https://github.com/zq/shell/blob/master/autoBestTrace.sh
#	Blog: https://github.com/Chennhaoo
#=================================================

if [ ! -f "besttrace2021" ]; then
    wget https://github.com/zq/shell/raw/master/besttrace2021
    # unzip besttrace4linux.zip
    chmod +x besttrace2021
fi

next() {
    printf "%-70s\n" "-" | sed 's/\s/-/g'
}

clear
next

ip_list=(219.141.147.210 202.96.209.133 58.60.188.222 202.106.50.1 210.22.97.1 210.21.196.6 221.179.155.161 211.136.112.200 120.196.165.24 202.112.14.151)
ip_addr=(北京电信 上海电信 深圳电信 北京联通 上海联通 深圳联通 北京移动 上海移动 深圳移动 成都教育网)
# ip_len=${#ip_list[@]}

for i in {0..9}
do
	echo ${ip_addr[$i]}
	./besttrace2021 -q 1 ${ip_list[$i]}
	next
done

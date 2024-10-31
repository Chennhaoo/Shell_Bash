#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: 三网回程路由详细测试
#	Author: ChennHaoo
#   参考：https://github.com/zq/shell/blob/master/autoBestTrace.sh  
#         https://github.com/fscarmen/warp_unlock
#         https://github.com/fscarmen/tools/blob/main/return.sh
#         https://github.com/masonr/yet-another-bench-script/blob/master/yabs.sh
#         https://github.com/sjlleo/nexttrace/blob/main/README_zh_CN.md
#         https://github.com/spiritLHLS/ecs
#
#	Blog: https://github.com/Chennhaoo
#
#   重要：若IP失效或提示404，请修改 $IPv4_IP 和 $IPv6_IP 部分IP
#=================================================

#定义参数
sh_ver="2024.10.31_06"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
BestTrace_dir="${file}/BestTrace"
BestTrace_file="${file}/BestTrace/besttrace_IP"
Nexttrace_dir="${file}/Nexttrace"
Nexttrace_file="${file}/Nexttrace/nexttrace_IP"
log="${file}/AutoTrace_Mtr.log"
true > $log
rep_time=$( date -R )

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Yellow_font_prefix="\033[33m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#检查当前账号是否为root，主要是后面要装软件
check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"	
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	[ -z "${release}" ] && echo -e "${Error} 未安装操作系统 !" && exit 1
	bit=`uname -m`

	# 主机架构判断
	ARCH=$(uname -m)
	if [[ $ARCH = *x86_64* ]]; then
		# 64-bit kernel
		bit="x64"
	elif [[ $ARCH = *i386* ]]; then
		# 32-bit kernel
		bit="x86"
	elif [[ $ARCH = *aarch* || $ARCH = *arm* ]]; then
		KERNEL_BIT=`getconf LONG_BIT`
		if [[ $KERNEL_BIT = *64* ]]; then
			# ARM 64-bit kernel
			bit="aarch64"
		else
			# ARM 32-bit kernel
			bit="arm"
		fi
		echo -e "\nARM 实验性质平台"
    elif [[ $ARCH = *mips* ]]; then
		# MIPS kernel
		bit="mips"
	else
		# 未知内核 
		echo -e "${Error} 无法受支持的系统 !" && exit 1
	fi

    #软件安装检查
	if  [[ "$(command -v wget)" == "" ]]; then
		echo -e "${Info} 开始安装 Wget ...."
		if [[ ${release} == "centos" ]]; then
			yum -y install Wget
		elif [[ ${release} == "debian" ]]; then	
			apt-get -y install Wget
		elif [[ ${release} == "ubuntu" ]]; then	
			apt-get -y install Wget	
		else
		 	echo -e "${Error} 无法判断您的系统 " && exit 1	
		fi
    elif  [[ "$(command -v curl)" == "" ]]; then
		echo -e "${Info} 开始安装 Curl ...."
		if [[ ${release} == "centos" ]]; then
			yum -y install curl
		elif [[ ${release} == "debian" ]]; then	
			apt-get -y install curl
		elif [[ ${release} == "ubuntu" ]]; then	
			apt-get -y install curl	
		else
		 	echo -e "${Error} 无法判断您的系统 " && exit 1	
		fi
    elif  [[ "$(command -v ping)" == "" ]]; then
		echo -e "${Info} 开始安装 Ping ...."
		if [[ ${release} == "centos" ]]; then
			yum -y install ping
		elif [[ ${release} == "debian" ]]; then	
			apt-get -y install ping
		elif [[ ${release} == "ubuntu" ]]; then	
			apt-get -y install ping	
		else
		 	echo -e "${Error} 无法判断您的系统 " && exit 1	
		fi
	fi    
}

#使用计数
statistics_of_run-times() {
    COUNT=$(
        curl -4 -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FChennhaoo%2FShell_Bash&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=&edge_flat=true" 2>&1 ||
            curl -6 -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FChennhaoo%2FShell_Bash&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=&edge_flat=true" 2>&1
    )
    #当天
    TODAY=$(expr "$COUNT" : '.*\s\([0-9]\{1,\}\)\s/.*')
    #累计
    TOTAL=$(expr "$COUNT" : '.*/\s\([0-9]\{1,\}\)\s.*')
}

#脚本版本更新
checkver() {
    running_version=$(sed -n '22s/sh_ver="\(.*\)"/\1/p' "$0")
    curl -L "https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh" -o AutoTrace_update.sh && chmod 777 AutoTrace_update.sh
    downloaded_version=$(sed -n '22s/sh_ver="\(.*\)"/\1/p' AutoTrace_update.sh)
    echo -e "${Info} 本地脚本版本为：${running_version} "
    echo -e "${Info} 最新脚本版本为：${downloaded_version} "
    if [ "$running_version" != "$downloaded_version" ]; then
        echo -e "${Info} 更新脚本从 ${sh_ver} 到 ${downloaded_version}"
        mv AutoTrace_update.sh "$0"
        ./AutoTrace.sh
    else
        echo -e "${Info} 本脚本已是最新，脚本无需更新 ！"
        rm -rf AutoTrace_update.sh*
    fi
}

#检测IPv4、IPv6状态
IP_Check(){
    #通过ping ip.sb这个网站，如果ping通了没有报错，再和后面比较，如果都有输出，则代表网络通的。这个主要用来测试只有IPV4或IPV6的机器是不是有网
    IPV4_CHECK=$((ping -4 -c 1 -W 4 ip.sb >/dev/null 2>&1 && echo true) || curl -s -m 4 -4 ip-api.com 2> /dev/null)
    IPV6_CHECK=$((ping -6 -c 1 -W 4 ip.sb >/dev/null 2>&1 && echo true) || curl -s -m 4 -6 ip.sb 2> /dev/null)
    if [[ -z "$IPV4_CHECK" && -z "$IPV6_CHECK" ]]; then
        echo -e
        echo -e "${Error} 未检测到 IPv4 和 IPv6 连接，请检查 DNS 问题..." && exit 1 
    fi

    #开始检测IPv4、IPv6前的参数配置
    #API_NET=("api.ip.sb")
    API_URL=("api.ip.sb/geoip")
    
    #IPv4网络探测
    IP_4=$(curl -s4m5 -A Mozilla https://$API_URL)
    WAN_4=$(expr "${IP_4}" : '.*ip\":[ ]*\"\([^"]*\).*')
    #如果IPv4不为空，就执行里面的
    if [ -n "$WAN_4" ]; then
      #输出IP的ISP
      ISP_4=$(expr "${IP_4}" : '.*isp\":[ ]*\"\([^"]*\).*')
      #输出IP的ASN
      ASN_4_Temp=$(echo $(curl -s4 http://ip-api.com/json/$WAN_4) | grep -Po '"as": *\K"[^"]*"')
      ASN_4=${ASN_4_Temp//\"}
      #输出IP的服务商
      Host_4_Temp=$(echo $(curl -s4 http://ip-api.com/json/$WAN_4) | grep -Po '"org": *\K"[^"]*"')
      Host_4=${Host_4_Temp//\"}
      #输出IP的国家，英文
      COUNTRY_4E=$(expr "${IP_4}" : '.*country\":[ ]*\"\([^"]*\).*')
      #输出IP的地址，英文
      City_4E=$(expr "${IP_4}" : '.*city\":[ ]*\"\([^"]*\).*')
      Region_4E=$(expr "${IP_4}" : '.*region\":[ ]*\"\([^"]*\).*')
      Region_code_4E=$(expr "${IP_4}" : '.*region_code\":[ ]*\"\([^"]*\).*')
      Location_4E="$City_4E, $Region_4E ($Region_code_4E)"
      #IP欺诈分数
      FRAUD_SCORE_4=$(curl -m10 -sL -H "Referer: https://scamalytics.com" \
      "https://scamalytics.com/ip/$WAN_4" | awk -F : '/Fraud Score/ {gsub(/[^0-9]/,"",$2); print $2}')
      #输出IP的类型：数据中心/家庭宽带/商业宽带/移动流量/内容分发网络/搜索引擎蜘蛛/教育网/未知
      #使用abuseipdb.com的API进行探测，每日1000次请求
      TYPE_4_Temp=$(curl -sG https://api.abuseipdb.com/api/v2/check \
      --data-urlencode "ipAddress=$WAN_4" \
      -d maxAgeInDays=90 \
      -d verbose \
      -H "Key: c97ab9480e282182aeac0408b788fad9e41d3ef5aa12d294b3fe8b50cfeb4edf43351bbe4870b066" \
      -H "Accept: application/json" | grep -Po '"usageType": *\K"[^"]*"' | sed "s#\\\##g" | sed 's/"//g;s/v//g')
      #老代码，已失效
      #TYPE_4_Temp=$(curl -4m5 -A Mozilla -sSL https://www.abuseipdb.com/check/"${WAN_4}" 2>/dev/null | grep -A2 '<th>Usage Type</th>' | tail -n 1 ) 
        if [[ ${TYPE_4_Temp} == "Data Center/Web Hosting/Transit" ]]; then
            TYPE_4="数据中心"
        elif [[ ${TYPE_4_Temp} == "Fixed Line ISP" ]]; then
            TYPE_4="家庭宽带"
        elif [[ ${TYPE_4_Temp} == "Commercial" ]]; then
            TYPE_4="商业宽带"
        elif [[ ${TYPE_4_Temp} == "Mobile ISP" ]]; then
            TYPE_4="移动流量"
        elif [[ ${TYPE_4_Temp} == "Content Delivery Network" ]]; then
            TYPE_4="内容分发网络(CDN)"
        elif [[ ${TYPE_4_Temp} == "Search Engine Spider" ]]; then
            TYPE_4="搜索引擎蜘蛛"
        elif [[ ${TYPE_4_Temp} == "University/College/School" ]]; then
            TYPE_4="教育网"
#        elif [[ ${TYPE_4_Temp} == "Unknown" ]]; then
#            TYPE_4="未知 IP 网络类型"
        elif [[ ${TYPE_4_Temp} == "" ]]; then
            TYPE_4="未知 IP 网络类型"             
        fi           
    fi  

    #IPv6网络探测
    IP_6=$(curl -s6m5 -A Mozilla https://$API_URL) &&
    WAN_6=$(expr "${IP_6}" : '.*ip\":[ ]*\"\([^"]*\).*')
    #如果IPv6不为空，就执行里面的
    if [ -n "$WAN_6" ]; then
      #输出IP的ISP
      ISP_6=$(expr "${IP_6}" : '.*isp\":[ ]*\"\([^"]*\).*')
      #输出IP的ASN
      ASN_6_Temp=$(echo $(curl -s6 http://ip-api.com/json/$WAN_6) | grep -Po '"as": *\K"[^"]*"')
      ASN_6=${ASN_6_Temp//\"}
      #输出IP的服务商
      Host_6_Temp=$(echo $(curl -s6 http://ip-api.com/json/$WAN_6) | grep -Po '"org": *\K"[^"]*"')
      Host_6=${Host_6_Temp//\"}
      #输出IP的国家，英文
      COUNTRY_6E=$(expr "${IP_6}" : '.*country\":[ ]*\"\([^"]*\).*')
      #输出IP的地址，英文
      City_6E=$(expr "${IP_6}" : '.*city\":[ ]*\"\([^"]*\).*')
      Region_6E=$(expr "${IP_6}" : '.*region\":[ ]*\"\([^"]*\).*')
      Region_code_6E=$(expr "${IP_6}" : '.*region_code\":[ ]*\"\([^"]*\).*')
      Location_6E="$City_6E, $Region_6E ($Region_code_6E)"
      #IP欺诈分数
      FRAUD_SCORE_6=$(curl -m10 -sL -H "Referer: https://scamalytics.com" \
      "https://scamalytics.com/ip/$WAN_6" | awk -F : '/Fraud Score/ {gsub(/[^0-9]/,"",$2); print $2}')
      #输出IP的类型：数据中心/家庭宽带/商业宽带/移动流量/内容分发网络/搜索引擎蜘蛛/教育网/未知
      #使用abuseipdb.com的API进行探测，每日1000次请求
      TYPE_6_Temp=$(curl -sG https://api.abuseipdb.com/api/v2/check \
      --data-urlencode "ipAddress=$WAN_6" \
      -d maxAgeInDays=90 \
      -d verbose \
      -H "Key: c97ab9480e282182aeac0408b788fad9e41d3ef5aa12d294b3fe8b50cfeb4edf43351bbe4870b066" \
      -H "Accept: application/json" | grep -Po '"usageType": *\K"[^"]*"' | sed "s#\\\##g" | sed 's/"//g;s/v//g')
      #老代码，已失效
      #TYPE_6_Temp=$(curl -6m5 -A Mozilla -sSL https://www.abuseipdb.com/check/"${WAN_6}" 2>/dev/null | grep -A2 '<th>Usage Type</th>' | tail -n 1 ) 
      	if [[ ${TYPE_6_Temp} == "Data Center/Web Hosting/Transit" ]]; then
            TYPE_6="数据中心"
        elif [[ ${TYPE_6_Temp} == "Fixed Line ISP" ]]; then
            TYPE_6="家庭宽带"
        elif [[ ${TYPE_6_Temp} == "Commercial" ]]; then
            TYPE_6="商业宽带"
        elif [[ ${TYPE_6_Temp} == "Mobile ISP" ]]; then
            TYPE_6="移动流量"
        elif [[ ${TYPE_6_Temp} == "Content Delivery Network" ]]; then
            TYPE_6="内容分发网络(CDN)"
        elif [[ ${TYPE_6_Temp} == "Search Engine Spider" ]]; then
            TYPE_6="搜索引擎蜘蛛"
        elif [[ ${TYPE_6_Temp} == "University/College/School" ]]; then
            TYPE_6="教育网"
#        elif [[ ${TYPE_6_Temp} == "Unknown" ]]; then
#            TYPE_6="未知 IP 网络类型" 
        elif [[ ${TYPE_6_Temp} == "" ]]; then
            TYPE_6="未知 IP 网络类型"               
        fi          
    fi

    #菜单栏统一输出参数
    if [[ -n ${WAN_4} ]]; then 
        IPv4_Print="${WAN_4}"
    else 
        IPv4_Print="无 IPv4"
    fi
    if [[ -n ${WAN_6} ]]; then 
        IPv6_Print="${WAN_6}"
    else 
        IPv6_Print="无 IPv6"
    fi
    #优先输出IPv4的ISP、ASN、IP服务商、国家、地址、网络信息
    if [[ -n ${WAN_4} ]]; then 
        ISP_Print="${ISP_4}"
        ASN_Print="${ASN_4}"
        Host_Print="${Host_4}"
        COUNTRY_Print="${COUNTRY_4E}"
        Location_Print="${Location_4E}"
        FRAUD_SCORE="${FRAUD_SCORE_4}"
        TYPE_Print="${TYPE_4}"
    elif [[ -n ${WAN_6} ]]; then 
        ISP_Print="${ISP_6}"
        ASN_Print="${ASN_6}"
        Host_Print="${Host_6}"
        COUNTRY_Print="${COUNTRY_6E}"
        Location_Print="${Location_6E}"
        FRAUD_SCORE="${FRAUD_SCORE_6}"
        TYPE_Print="${TYPE_6}"
    else
        ISP_Print="网络连接出错，无法探测"
        ASN_Print="网络连接出错，无法探测"
        Host_Print="网络连接出错，无法探测"
        COUNTRY_Print="网络连接出错，无法探测"
        Location_Print="网络连接出错，无法探测"
        FRAUD_SCORE="网络连接出错，无法探测"
        TYPE_Print="网络连接出错，无法探测"   
    fi    
}

#BestTrace IPv4 回程代码 中文输出 
BT_Ipv4_mtr_CN(){
    if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n$5 Traceroute to $4 (TCP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${BestTrace_file} -g cn -q 1 -n -T -m $3 $1 | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\n$5 Tracecroute to $4 (ICMP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${BestTrace_file} -g cn -q 1 -n -m $3 $1 | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi
}

#BestTrace IPv4 IP库三网回程路由测试 中文输出  (若需修改IP，可修改IPv4_IP代码段；若需修改TCP/ICMP，可修改BestTrace_Mode代码段)
BT_IPv4_IP_CN_Mtr(){
    #检测是否存在 IPv4
    if  [[ "${WAN_4}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv4 地址" && exit 1
    fi
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载BestTrace主程序
    BestTrace_Ver
    #载入IPv4库     
    IPv4_IP
    #载入BestTrace参数
    BestTrace_Mode
    #开始测试IPv4库回程路由，第5个块是表示节点序号的，增删节点都要修改
    clear  
 	BT_Ipv4_mtr_CN "${IPv4_1}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_1_name}" "No:1/9"
    BT_Ipv4_mtr_CN "${IPv4_2}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_2_name}" "No:2/9"
    BT_Ipv4_mtr_CN "${IPv4_3}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_3_name}" "No:3/9"
    BT_Ipv4_mtr_CN "${IPv4_4}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_4_name}" "No:4/9"
    BT_Ipv4_mtr_CN "${IPv4_5}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_5_name}" "No:5/9"
    BT_Ipv4_mtr_CN "${IPv4_6}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_6_name}" "No:6/9"
    BT_Ipv4_mtr_CN "${IPv4_7}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_7_name}" "No:7/9"
    BT_Ipv4_mtr_CN "${IPv4_8}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_8_name}" "No:8/9"
    BT_Ipv4_mtr_CN "${IPv4_9}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_9_name}" "No:9/9"
    #保留IPv4回程路由日志
    echo -e "${Info} 回程路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除BestTrace执行文件
    BestTrace_Dle     
}

#BestTrace IPv4 回程代码 英文输出 
BT_Ipv4_mtr_EN(){
    if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n$5 Traceroute to $4 (TCP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${BestTrace_file} -g en -q 1 -n -T -m $3 $1 | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\n$5 Tracecroute to $4 (ICMP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${BestTrace_file} -g en -q 1 -n -m $3 $1 | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi     
}

#BestTrace IPv4 IP库三网回程路由测试 英文输出  (若需修改IP，可修改IPv4_IP代码段；若需修改TCP/ICMP，可修改BestTrace_Mode代码段)
BT_IPv4_IP_EN_Mtr(){
    #检测是否存在 IPv4
    if  [[ "${WAN_4}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv4 地址" && exit 1
    fi     
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载BestTrace主程序
    BestTrace_Ver
    #载入IPv4库     
    IPv4_IP
    #载入BestTrace参数
    BestTrace_Mode
    #开始测试IPv4库回程路由，第5个块是表示节点序号的，增删节点都要修改
    clear  
 	BT_Ipv4_mtr_EN "${IPv4_1}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_1_name}" "No:1/9"
    BT_Ipv4_mtr_EN "${IPv4_2}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_2_name}" "No:2/9"
    BT_Ipv4_mtr_EN "${IPv4_3}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_3_name}" "No:3/9"
    BT_Ipv4_mtr_EN "${IPv4_4}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_4_name}" "No:4/9"
    BT_Ipv4_mtr_EN "${IPv4_5}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_5_name}" "No:5/9"
    BT_Ipv4_mtr_EN "${IPv4_6}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_6_name}" "No:6/9"
    BT_Ipv4_mtr_EN "${IPv4_7}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_7_name}" "No:7/9"
    BT_Ipv4_mtr_EN "${IPv4_8}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_8_name}" "No:8/9"
    BT_Ipv4_mtr_EN "${IPv4_9}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_9_name}" "No:9/9"
    #保留IPv4回程路由日志
    echo -e "${Info} 回程路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除BestTrace执行文件
    BestTrace_Dle      
}

#Nexttrace IPv4 回程代码 中文输出 
NT_Ipv4_mtr_CN(){
    if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n$5 Traceroute to $4 (TCP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -T -m $3 $1 | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\n$5 Tracecroute to $4 (ICMP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -m $3 $1 | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi   
}

#Nexttrace IPv4 IP库三网回程路由测试 中文输出  (若需修改IP，可修改IPv4_IP代码段；若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_IPv4_IP_CN_Mtr(){
    #检测是否存在 IPv4
    if  [[ "${WAN_4}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv4 地址" && exit 1
    fi     
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入IPv4库     
    IPv4_IP
    #载入Nexttrace参数
    Nexttrace_Mode
    #开始测试IPv4库回程路由，第5个块是表示节点序号的，增删节点都要修改
    clear    
 	NT_Ipv4_mtr_CN "${IPv4_1}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_1_name}" "No:1/9"
    NT_Ipv4_mtr_CN "${IPv4_2}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_2_name}" "No:2/9"
    NT_Ipv4_mtr_CN "${IPv4_3}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_3_name}" "No:3/9"
    NT_Ipv4_mtr_CN "${IPv4_4}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_4_name}" "No:4/9"
    NT_Ipv4_mtr_CN "${IPv4_5}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_5_name}" "No:5/9"
    NT_Ipv4_mtr_CN "${IPv4_6}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_6_name}" "No:6/9"
    NT_Ipv4_mtr_CN "${IPv4_7}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_7_name}" "No:7/9"
    NT_Ipv4_mtr_CN "${IPv4_8}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_8_name}" "No:8/9"
    NT_Ipv4_mtr_CN "${IPv4_9}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_9_name}" "No:9/9"
    #保留IPv4回程路由日志
    echo -e "${Info} 回程路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

#Nexttrace IPv4 回程代码 英文输出 
NT_Ipv4_mtr_EN(){
    if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n$5 Traceroute to $4 (TCP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -T -m $3 $1 | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\n$5 Tracecroute to $4 (ICMP Mode, Max $3 Hop, IPv4)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -m $3 $1 | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi   
}

#Nexttrace IPv4 IP库三网回程路由测试 英文输出  (若需修改IP，可修改IPv4_IP代码段；若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_IPv4_IP_EN_Mtr(){
    #检测是否存在 IPv4
    if  [[ "${WAN_4}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv4 地址" && exit 1
    fi     
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入IPv4库     
    IPv4_IP
    #载入Nexttrace参数
    Nexttrace_Mode
    #开始测试IPv4库回程路由，第5个块是表示节点序号的，增删节点都要修改
    clear    
 	NT_Ipv4_mtr_EN "${IPv4_1}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_1_name}" "No:1/9"
    NT_Ipv4_mtr_EN "${IPv4_2}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_2_name}" "No:2/9"
    NT_Ipv4_mtr_EN "${IPv4_3}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_3_name}" "No:3/9"
    NT_Ipv4_mtr_EN "${IPv4_4}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_4_name}" "No:4/9"
    NT_Ipv4_mtr_EN "${IPv4_5}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_5_name}" "No:5/9"
    NT_Ipv4_mtr_EN "${IPv4_6}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_6_name}" "No:6/9"
    NT_Ipv4_mtr_EN "${IPv4_7}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_7_name}" "No:7/9"
    NT_Ipv4_mtr_EN "${IPv4_8}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_8_name}" "No:8/9"
    NT_Ipv4_mtr_EN "${IPv4_9}" "${Net_Mode}" "${Hop_Mode}" "${IPv4_9_name}" "No:9/9"
    #保留IPv4回程路由日志
    echo -e "${Info} 回程路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

#IP v4 库（可以是IP，也可以是域名）
IPv4_IP(){
    #电信
    IPv4_1="gd-ct-v4.ip.zstaticcdn.com:80"
    IPv4_1_name="中国 广东 电信"
    
    IPv4_2="sh-ct-v4.ip.zstaticcdn.com:80"
    IPv4_2_name="中国 上海 电信"
    
    IPv4_3="bj-ct-v4.ip.zstaticcdn.com:80"
    IPv4_3_name="中国 北京 电信"   
    #联通
    IPv4_4="gd-cu-v4.ip.zstaticcdn.com:80"
    IPv4_4_name="中国 广东 联通"
    
    IPv4_5="sh-cu-v4.ip.zstaticcdn.com:80"
    IPv4_5_name="中国 上海 联通"
    
    IPv4_6="bj-cu-v4.ip.zstaticcdn.com:80"
    IPv4_6_name="中国 北京 联通"
    #移动
    IPv4_7="gd-cm-v4.ip.zstaticcdn.com:80"
    IPv4_7_name="中国 广东 移动"
    
    IPv4_8="sh-cm-v4.ip.zstaticcdn.com:80"
    IPv4_8_name="中国 上海 移动"
    
    IPv4_9="bj-cm-v4.ip.zstaticcdn.com:80"
    IPv4_9_name="中国 北京 移动"
}

#Nexttrace IPv6 回程代码 中文输出 
NT_Ipv6_mtr_CN(){
    if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n$5 Traceroute to $4 (TCP Mode, Max $3 Hop, IPv6)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -T -m $3 $1 | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\n$5 Tracecroute to $4 (ICMP Mode, Max $3 Hop, IPv6)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -m $3 $1 | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi   
}

#Nexttrace IPv6 IP库三网回程路由测试 中文输出  (若需修改IP，可修改IPv6_IP代码段；若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_IPv6_IP_CN_Mtr(){
    #检测是否存在 IPv6
    if  [[ "${WAN_6}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv6 地址" && exit 1
    fi     
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入IPv4库     
    IPv6_IP
    #载入Nexttrace参数
    Nexttrace_Mode
    #开始测试IPv6库回程路由，第5个块是表示节点序号的，增删节点都要修改
    clear    
 	NT_Ipv6_mtr_CN "${IPv6_1}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_1_name}" "No:1/9"
    NT_Ipv6_mtr_CN "${IPv6_2}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_2_name}" "No:2/9"
    NT_Ipv6_mtr_CN "${IPv6_3}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_3_name}" "No:3/9" 
    NT_Ipv6_mtr_CN "${IPv6_4}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_4_name}" "No:4/9" 
    NT_Ipv6_mtr_CN "${IPv6_5}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_5_name}" "No:5/9" 
    NT_Ipv6_mtr_CN "${IPv6_6}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_6_name}" "No:6/9" 
    NT_Ipv6_mtr_CN "${IPv6_7}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_7_name}" "No:7/9" 
    NT_Ipv6_mtr_CN "${IPv6_8}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_8_name}" "No:8/9" 
    NT_Ipv6_mtr_CN "${IPv6_9}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_9_name}" "No:9/9" 
    #保留IPv6回程路由日志
    echo -e "${Info} 回程路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

#Nexttrace IPv6 回程代码 英文输出 
NT_Ipv6_mtr_EN(){
    if [ "$2" = "tcp" ] || [ "$2" = "TCP" ]; then
        echo -e "\n$5 Traceroute to $4 (TCP Mode, Max $3 Hop, IPv6)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -T -m $3 $1 | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\n$5 Tracecroute to $4 (ICMP Mode, Max $3 Hop, IPv6)" | tee -a $log
        echo -e "===================================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -m $3 $1 | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi     
}

#IPv6 IP库三网回程路由测试 英文输出  (若需修改IP，可修改IPv6_IP代码段；若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_IPv6_IP_EN_Mtr(){
    #检测是否存在 IPv6
    if  [[ "${WAN_6}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv6 地址" && exit 1
    fi     
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入IPv4库     
    IPv6_IP
    #载入Nexttrace参数
    Nexttrace_Mode
    #开始测试IPv6库回程路由，第5个块是表示节点序号的，增删节点都要修改
    clear  
 	NT_Ipv6_mtr_EN "${IPv6_1}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_1_name}" "No:1/9"
    NT_Ipv6_mtr_EN "${IPv6_2}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_2_name}" "No:2/9"
    NT_Ipv6_mtr_EN "${IPv6_3}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_3_name}" "No:3/9"  
    NT_Ipv6_mtr_EN "${IPv6_4}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_4_name}" "No:4/9" 
    NT_Ipv6_mtr_EN "${IPv6_5}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_5_name}" "No:5/9" 
    NT_Ipv6_mtr_EN "${IPv6_6}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_6_name}" "No:6/9" 
    NT_Ipv6_mtr_EN "${IPv6_7}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_7_name}" "No:7/9" 
    NT_Ipv6_mtr_EN "${IPv6_8}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_8_name}" "No:8/9" 
    NT_Ipv6_mtr_EN "${IPv6_9}" "${Net_Mode}" "${Hop_Mode}" "${IPv6_9_name}" "No:9/9" 
    #保留IPv6回程路由日志
    echo -e "${Info} 回程路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle  
}

#IP v6 库（可以是IP，也可以是域名）
IPv6_IP(){
    #电信
    IPv6_1="bj-ct-v6.ip.zstaticcdn.com:80"
    IPv6_1_name="中国 北京 电信"
    
    IPv6_2="sh-ct-v6.ip.zstaticcdn.com:80"
    IPv6_2_name="中国 上海 电信"
    
    IPv6_3="gd-ct-v6.ip.zstaticcdn.com:80"
    IPv6_3_name="中国 广东 电信" 

    #联通
    IPv6_4="bj-cu-v6.ip.zstaticcdn.com:80"
    IPv6_4_name="中国 北京 联通" 

    IPv6_5="sh-cu-v6.ip.zstaticcdn.com:80"
    IPv6_5_name="中国 上海 联通"   

    IPv6_6="gd-cu-v6.ip.zstaticcdn.com:80"
    IPv6_6_name="中国 广东 联通" 
    
    #移动
    IPv6_7="bj-cm-v6.ip.zstaticcdn.com:80"
    IPv6_7_name="中国 北京 移动" 

    IPv6_8="sh-cm-v6.ip.zstaticcdn.com:80"
    IPv6_8_name="中国 上海 移动"   

    IPv6_9="gd-cm-v6.ip.zstaticcdn.com:80"
    IPv6_9_name="中国 广东 移动"    
}


#参数配置区域
#==========================================================================================
#BestTrace 参数设置
BestTrace_Mode(){
    #使用TCP SYN进行探测，如需ICMP，直接改为ICMP即可
    Net_Mode="TCP"
    #最大跳数（最大生存时间值），默认 30
    Hop_Mode="30"
}

#Nexttrace 参数设置
Nexttrace_Mode(){
    #使用TCP SYN进行探测，如需ICMP，直接改为ICMP即可
    Net_Mode="TCP"
    #最大跳数（最大生存时间值），默认 30
    Hop_Mode="30"
}

#当下目录BestTrace主程序文件删除
BestTrace_Dle(){
    rm -rf "${BestTrace_dir}"
	if [[ -e ${BestTrace_dir} ]]; then
		echo -e "${Error} 删除 BestTrace 文件失败，请手动删除 ${BestTrace_file}"
	else	
		echo -e "${Info} 已删除 BestTrace 文件"
	fi   
}

#当下目录Nexttrace主程序文件删除
Nexttrace_Dle(){
    rm -rf "${Nexttrace_dir}"
	if [[ -e ${Nexttrace_dir} ]]; then
		echo -e "${Error} 删除 Nexttrace 文件失败，请手动删除 ${Nexttrace_dir}"
	else	
		echo -e "${Info} 已删除 Nexttrace 文件"
	fi  
}

#删除当前目录下的路由路径文件，共用
Log_Dle(){
    rm -rf "${log}"
	if [[ -e ${log} ]]; then
		echo -e "${Error} 删除 路由路径 文件失败，请手动删除 ${log}"
	else	
		echo -e "${Info} 已删除 路由路径 文件"
	fi  
}

#前置参数启动
AutoTrace_Start(){
    #检测当下目录BestTrace文件夹，如有则删除
    BestTrace_Dle
    #检测当下目录Nexttrace文件夹，如有则删除
    Nexttrace_Dle
    #删除当前目录下的路由路径文件
    Log_Dle
    #开始生成本次报告的时间
    echo -e "${Info} 本报告生成时间：${rep_time}" | tee -a $log  
}

#BestTrace版本下载
BestTrace_Ver(){
    if [[ ${release} == "centos" ]]; then
        BestTrace_bit
        echo -e "${Info} CentOS BestTrace 检测已下载 !" | tee -a $log
    elif [[ ${release} == "debian" ]]; then 
        BestTrace_bit
        echo -e "${Info} Debian BestTrace 检测已下载 !" | tee -a $log      
    elif [[ ${release} == "ubuntu" ]]; then 
        BestTrace_bit
        echo -e "${Info} Ubuntu BestTrace 检测已下载 !" | tee -a $log 
    else
        echo -e "${Error} 无法受支持的系统 !" && exit 1
    fi
}

#BestTrace 系统位数版本下载
BestTrace_bit(){
    echo -e "${Info} 开始根据系统位数下载 BestTrace !"
    mkdir "${BestTrace_dir}"
    echo -e "${Info} 当前目录建立 BestTrace 文件夹 !"
    if [[ ${bit} == "x64" ]]; then 
        if ! wget --no-check-certificate -O ${BestTrace_dir}/besttrace_IP https://github.com/Chennhaoo/Shell_Bash/raw/master/BestTrace/besttrace; then
            echo -e "${Error} BestTrace_x64 下载失败 !" && exit 1
        else
            echo -e "${Info} BestTrace_x64 下载完成 !" | tee -a $log
        fi
    elif [[ ${bit} == "x86" ]]; then
            if ! wget --no-check-certificate -O ${BestTrace_dir}/besttrace_IP https://github.com/Chennhaoo/Shell_Bash/raw/master/BestTrace/besttrace32; then
            echo -e "${Error} BestTrace_x32 下载失败 !" && exit 1
        else
            echo -e "${Info} BestTrace_x32 下载完成 !" | tee -a $log
        fi 
    elif [[ ${bit} == "aarch64" ]]; then
            if ! wget --no-check-certificate -O ${BestTrace_dir}/besttrace_IP https://github.com/Chennhaoo/Shell_Bash/raw/master/BestTrace/besttracearm; then
            echo -e "${Error} BestTrace_ARM 下载失败 !" && exit 1
        else
            echo -e "${Info} BestTrace_ARM 下载完成 !" | tee -a $log
        fi
    elif [[ ${bit} == "arm" ]]; then
            if ! wget --no-check-certificate -O ${BestTrace_dir}/besttrace_IP https://github.com/Chennhaoo/Shell_Bash/raw/master/BestTrace/besttracearm; then
            echo -e "${Error} BestTrace_ARM 下载失败 !" && exit 1
        else
            echo -e "${Info} BestTrace_ARM 下载完成 !" | tee -a $log
        fi
    else
        echo -e "${Error} 无法受支持的系统 !" && exit 1
    fi
    #检查BestTrace文件是否存在
    if [[ -e ${BestTrace_file} ]]; then
        echo -e "${Info} BestTrace 已下载 !"
        chmod +x "${BestTrace_file}"
    else
        echo -e "${Error} 未检测到 BestTrace 文件，请查看 ${BestTrace_dir} 目录文件是否存在!" && exit 1       
    fi
}

#Nexttrace版本下载
Nexttrace_Ver(){
    if [[ ${release} == "centos" ]]; then
        Nexttrace_bit
        echo -e "${Info} CentOS Nexttrace 检测已下载 !" | tee -a $log
    elif [[ ${release} == "debian" ]]; then 
        Nexttrace_bit
        echo -e "${Info} Debian Nexttrace 检测已下载 !" | tee -a $log      
    elif [[ ${release} == "ubuntu" ]]; then 
        Nexttrace_bit
        echo -e "${Info} Ubuntu Nexttrace 检测已下载 !" | tee -a $log 
    else
        echo -e "${Error} 无法受支持的系统 !" && exit 1
    fi
}

#Nexttrace 系统位数版本下载
Nexttrace_bit(){
    echo -e "${Info} 开始根据系统位数下载 Nexttrace !"
    mkdir "${Nexttrace_dir}"
    echo -e "${Info} 当前目录建立 Nexttrace 文件夹 !"
    #网址直接获取特定文件最终版
    #https://github.com/sjlleo/nexttrace/releases/latest/download/nexttrace_linux_386 
    #通过Github API获取最新版本号
    local response=$(curl -L -s https://api.github.com/repos/sjlleo/nexttrace/releases/latest)
    local NT_Ver=$(echo "$response" | grep -Po '"tag_name": *\K"[^"]*"')
    local NT_Ver=${NT_Ver//\"}
    echo -e "${Info} Nexttrace最新版本为 $NT_Ver" | tee -a $log 
    #开始分版本下载
    if [[ ${bit} == "x64" ]]; then 
        if ! wget --no-check-certificate -O ${Nexttrace_dir}/nexttrace_IP https://github.com/sjlleo/nexttrace/releases/download/$NT_Ver/nexttrace_linux_amd64; then
            echo -e "${Error} Nexttrace_x64 下载失败 !" && exit 1
        else
            echo -e "${Info} Nexttrace_x64 下载完成 !" | tee -a $log
        fi
    elif [[ ${bit} == "x86" ]]; then
            if ! wget --no-check-certificate -O ${Nexttrace_dir}/nexttrace_IP https://github.com/sjlleo/nexttrace/releases/download/$NT_Ver/nexttrace_linux_386; then
            echo -e "${Error} Nexttrace_x32 下载失败 !" && exit 1
        else
            echo -e "${Info} Nexttrace_x32 下载完成 !" | tee -a $log
        fi 
    elif [[ ${bit} == "aarch64" ]]; then
            if ! wget --no-check-certificate -O ${Nexttrace_dir}/nexttrace_IP https://github.com/sjlleo/nexttrace/releases/download/$NT_Ver/nexttrace_linux_arm64; then
            echo -e "${Error} Nexttrace_ARM_X64 下载失败 !" && exit 1
        else
            echo -e "${Info} Nexttrace_ARM_X64 下载完成 !" | tee -a $log
        fi
    elif [[ ${bit} == "arm" ]]; then
            if ! wget --no-check-certificate -O ${Nexttrace_dir}/nexttrace_IP https://github.com/sjlleo/nexttrace/releases/download/$NT_Ver/nexttrace_linux_armv7; then
            echo -e "${Error} Nexttrace_ARM_X32 下载失败 !" && exit 1
        else
            echo -e "${Info} Nexttrace_ARM_X32 下载完成 !" | tee -a $log
        fi
    elif [[ ${bit} == "mips" ]]; then
            if ! wget --no-check-certificate -O ${Nexttrace_dir}/nexttrace_IP https://github.com/sjlleo/nexttrace/releases/download/$NT_Ver/nexttrace_linux_mips; then
            echo -e "${Error} Nexttrace_MIPS 下载失败 !" && exit 1
        else
            echo -e "${Info} Nexttrace_MIPS 下载完成 !" | tee -a $log
        fi
    else
        echo -e "${Error} 无法受支持的系统 !" && exit 1
    fi
    #检查Nexttrace文件是否存在
    if [[ -e ${Nexttrace_file} ]]; then
        echo -e "${Info} Nexttrace 已下载 !"
        chmod +x "${Nexttrace_file}"
    else
        echo -e "${Error} 未检测到 Nexttrace 文件，请查看 ${Nexttrace_dir} 目录文件是否存在!" && exit 1       
    fi
}


###到指定IP路由测试部分    开始========================================================

#到指定IP路由测试 主菜单
Specify_IP(){
	clear
echo -e " 请选择需要的测试项（TCP Mode）
————————————————————————————————————
${Green_font_prefix} 1. ${Font_color_suffix}本机到指定 IPv4 路由 中文 输出 Nexttrace库（可指定端口）
${Green_font_prefix} 2. ${Font_color_suffix}本机到指定 IPv4 路由 英文 输出 Nexttrace库（可指定端口）
${Green_font_prefix} 3. ${Font_color_suffix}本机到指定 IPv6 路由 中文 输出 Nexttrace库（可指定端口）
${Green_font_prefix} 4. ${Font_color_suffix}本机到指定 IPv6 路由 英文 输出 Nexttrace库（可指定端口）
    "
    stty erase '^H' && read -p " 请输入数字 [1-4] (默认: 取消):" Specify_IP_num
    [[ -z ${Specify_IP_num} ]] && echo "已取消..." && exit 1 
	if [[ ${Specify_IP_num} == "1" ]]; then
		echo -e "${Info} 您选择的是：本机到指定 IPv4 路由 中文 输出 Nexttrace库（可指定端口），即将开始测试!
		"
        sleep 3s
        NT_Specify_IPv4_CN_Mtr
    elif [[ ${Specify_IP_num} == "2" ]]; then
		echo -e "${Info} 您选择的是：本机到指定 IPv4 路由 英文 输出 Nexttrace库（可指定端口），即将开始测试!
		"
        sleep 3s	
        NT_Specify_IPv4_EN_Mtr
    elif [[ ${Specify_IP_num} == "3" ]]; then
		echo -e "${Info} 您选择的是：本机到指定 IPv6 路由 中文 输出 Nexttrace库（可指定端口），即将开始测试!
		"
        sleep 3s	
        NT_Specify_IPv6_CN_Mtr
    elif [[ ${Specify_IP_num} == "4" ]]; then
		echo -e "${Info} 您选择的是：本机到指定 IPv6 路由 英文 输出 Nexttrace库（可指定端口），即将开始测试!
		"
        sleep 3s
        NT_Specify_IPv6_EN_Mtr
	else
		echo -e "${Error} 请输入正确的数字 [1-4]" && exit 1
	fi
}


#IPv4输入模块 IP检查
Int_IPV4(){
    read -e -p "请输入目标 IPv4：" Int_IPV4_IP
    [[ -z "${Int_IPV4_IP}" ]] && echo -e "${Error} 未输入 IP，已退出" && exit 1 
    #检查IP
    Check_Int_IPV4
}

#IPv4输入模块 端口检查  //因为BestTrace不支持指定端口
Int_IPV4_P(){
    read -e -p "请输入指定的端口（默认 80）：" Int_IPV4_Prot
    [[ -z "${Int_IPV4_Prot}" ]] && Int_IPV4_Prot="80"
    echo -e "${Info} 正在检测输入 端口 合法性"
    #判断端口是否为数字
    echo "${Int_IPV4_Prot}" |grep -Eq '[^0-9]' && echo -e "${Error} 请输入有效端口" && exit 1
    #判断端口是否在 1-65535 之间，-ge 1是指大于等于1，-le 65535是指小于等于65535，本段话是指输入端口如果大于等于1，小于等于65535时，则为真
#   if [ [ ${Int_IPV4_Prot} -ge 1 ] && [ ${Int_IPV4_Prot} -le 65535 ] ]; then
#       echo -e "${Info} 端口有效"
#   else
#       echo "${Error} 请输入 1-65535 之间的端口" && exit 1
#   fi
    #判断端口是否在 1-65535 之间，-lt 1是指小于1，-gt 65535是指大于65535，本段话是指输入端口如果小于1，大于65535时，则为真
    if [[ "${Int_IPV4_Prot}" -lt 1 || "${Int_IPV4_Prot}" -gt 65535 ]]; then
        echo -e "${Error} 输入的端口${Green_font_prefix}${Int_IPV4_Prot}${Font_color_suffix}有误，请输入 1-65535 之间的端口" && exit 1  
    fi
}

#IPv6输入模块
Int_IPV6(){
    read -e -p "请输入目标 IPv6：" Int_IPV6_IP
     [[ -z "${Int_IPV6_IP}" ]] && echo -e "${Error} 未输入 IP，已退出" && exit 1 
    #检查IP
    Check_Int_IPV6
    read -e -p "请输入指定的端口（默认 80）：" Int_IPV6_Prot
    [[ -z "${Int_IPV6_Prot}" ]] && Int_IPV6_Prot="80"
    #判断端口是否为数字
    echo -e "${Info} 正在检测输入 端口 合法性"
    echo "${Int_IPV6_Prot}" |grep -Eq '[^0-9]' && echo -e "${Error} 请输入有效端口" && exit 1
    #判断端口是否在 1-65535 之间，-lt 1是指小于1，-gt 65535是指大于65535，本段话是指输入端口如果小于1，大于65535时，则为真 
    if [[ "${Int_IPV6_Prot}" -lt 1 || "${Int_IPV6_Prot}" -gt 65535 ]]; then
        echo -e "${Error} 输入的端口${Green_font_prefix}${Int_IPV6_Prot}${Font_color_suffix}有误，请输入 1-65535 之间的端口" && exit 1  
    fi
}

#检测输入的IP是否为IPv4
Check_Int_IPV4(){
    echo -e "${Info} 正在检测输入 IP 连通性"
    #检测本机是否存在 IPv4
    if  [[ "${WAN_4}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv4 地址，无法测试到指定 IPv4 路由" && exit 1
    fi
    #检测输入IP是否为IPV4，PING得通就输出true，后面判断不为空就表示是IPV4
    PING_IPV4_CHECK=$(ping -4 -c 4 -W 4 "${Int_IPV4_IP}" >/dev/null 2>&1 && echo true) 
    if [[ -z "${PING_IPV4_CHECK}" ]]; then
        echo -e
        echo -e "${Error} 输入的${Green_font_prefix}${Int_IPV4_IP}${Font_color_suffix}不是有效的 IPv4 地址，或无法 Ping 通，是否忽略错误继续？[y/N]" && echo
        stty erase '^H' && read -p "(默认: y):" unyn 
        if [[ ${unyn} == [Nn] ]]; then
            echo && echo -e "${Info} 已取消..." && exit 1
        fi
    fi     
}

#检测输入的IP是否为IPv6
Check_Int_IPV6(){
    echo -e "${Info} 正在检测输入 IP 连通性"
    #检测本机是否存在 IPv6
    if  [[ "${WAN_6}" == "" ]]; then
        echo -e "${Error} 本机没有 IPv6 地址，无法测试到指定 IPv6 路由" && exit 1
    fi
    #检测输入IP是否为IPV6，PING得通就输出true，后面判断不为空就表示是IPV6
    PING_IPV6_CHECK=$(ping -6 -c 4 -W 4 "${Int_IPV6_IP}" >/dev/null 2>&1 && echo true) 
    if [[ -z "${PING_IPV6_CHECK}" ]]; then
        echo -e
        echo -e "${Error} 输入的${Green_font_prefix}${Int_IPV6_IP}${Font_color_suffix}不是有效的 IPv6 地址，或无法 Ping 通，是否忽略错误继续？[y/N]" && echo
        stty erase '^H' && read -p "(默认: y):" unyn 
        if [[ ${unyn} == [Nn] ]]; then
            echo && echo -e "${Info} 已取消..." && exit 1
        fi
    fi     
}

#BestTrace IPv4 到指定IP路由测试 中文输出  (若需修改TCP/ICMP，可修改BestTrace_Mode代码段)
BT_Specify_IPv4_CN_Mtr(){
    #IP输入
    Int_IPV4    
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载BestTrace主程序
    BestTrace_Ver
    #载入BestTrace参数
    BestTrace_Mode
    clear
    #开始测试到指定IPv4路由
    if [ "${Net_Mode}" = "tcp" ] || [ "${Net_Mode}" = "TCP" ]; then
        echo -e "\nTraceroute to "${Int_IPV4_IP}" (TCP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${BestTrace_file} -g cn -q 1 -n -T -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    elif [ "${Net_Mode}" = "icmp" ] || [ "${Net_Mode}" = "ICMP" ]; then
        echo -e "\nTracecroute to "${Int_IPV4_IP}" (ICMP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${BestTrace_file} -g cn -q 1 -n -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi 
    #保留IPv4路由日志
    echo -e "${Info} 路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除BestTrace执行文件
    BestTrace_Dle  
}

#BestTrace IPv4 到指定IP路由测试 英文输出  (若需修改TCP/ICMP，可修改BestTrace_Mode代码段)
BT_Specify_IPv4_EN_Mtr(){
    #IP输入
    Int_IPV4
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载BestTrace主程序
    BestTrace_Ver
    #载入BestTrace参数
    BestTrace_Mode
    clear
    #开始测试到指定IPv4路由
    if [ "${Net_Mode}" = "tcp" ] || [ "${Net_Mode}" = "TCP" ]; then
        echo -e "\nTraceroute to "${Int_IPV4_IP}" (TCP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${BestTrace_file} -g en -q 1 -n -T -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    elif [ "${Net_Mode}" = "icmp" ] || [ "${Net_Mode}" = "ICMP" ]; then
        echo -e "\nTracecroute to "${Int_IPV4_IP}" (ICMP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${BestTrace_file} -g en -q 1 -n -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi 
    #保留IPv4路由日志
    echo -e "${Info} 路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除BestTrace执行文件
    BestTrace_Dle  
}

#Nexttrace IPv4 到指定IP路由测试 中文输出，可指定端口(若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_Specify_IPv4_CN_Mtr(){   
    #IP输入 端口输入
    Int_IPV4
    Int_IPV4_P
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入Nexttrace参数
    Nexttrace_Mode
    clear
    #开始测试到指定IPv4路由  
    if [ "${Net_Mode}" = "tcp" ] || [ "${Net_Mode}" = "TCP" ]; then
        echo -e "\nTraceroute to "${Int_IPV4_IP}", Port:"${Int_IPV4_Prot}" (TCP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -T -p "${Int_IPV4_Prot}" -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\nTracecroute to "${Int_IPV4_IP}", Port:"${Int_IPV4_Prot}" (ICMP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -p "${Int_IPV4_Prot}" -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi  
    #保留IPv4路由日志
    echo -e "${Info} 路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

#Nexttrace IPv4 到指定IP路由测试 英文输出，可指定端口(若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_Specify_IPv4_EN_Mtr(){   
    #IP输入 端口输入
    Int_IPV4
    Int_IPV4_P
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入Nexttrace参数
    Nexttrace_Mode
    clear
    #开始测试到指定IPv4路由  
    if [ "${Net_Mode}" = "tcp" ] || [ "${Net_Mode}" = "TCP" ]; then
        echo -e "\nTraceroute to "${Int_IPV4_IP}", Port:"${Int_IPV4_Prot}" (TCP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -T -p "${Int_IPV4_Prot}" -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\nTracecroute to "${Int_IPV4_IP}", Port:"${Int_IPV4_Prot}" (ICMP Mode, Max "${Hop_Mode}" Hop, IPv4)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -p "${Int_IPV4_Prot}" -m "${Hop_Mode}" "${Int_IPV4_IP}" | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi  
    #保留IPv4路由日志
    echo -e "${Info} 路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

#Nexttrace IPv6 到指定IP路由测试 中文输出，可指定端口(若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_Specify_IPv6_CN_Mtr(){   
    #IP输入 端口输入
    Int_IPV6
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入Nexttrace参数
    Nexttrace_Mode
    clear
    #开始测试到指定IPv4路由  
    if [ "${Net_Mode}" = "tcp" ] || [ "${Net_Mode}" = "TCP" ]; then
        echo -e "\nTraceroute to "${Int_IPV6_IP}", Port:"${Int_IPV6_Prot}" (TCP Mode, Max "${Hop_Mode}" Hop, IPv6)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -T -p "${Int_IPV6_Prot}" -m "${Hop_Mode}" "${Int_IPV6_IP}" | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\nTracecroute to "${Int_IPV6_IP}", Port:"${Int_IPV6_Prot}" (ICMP Mode, Max "${Hop_Mode}" Hop, IPv6)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g cn -q 1 -n -p "${Int_IPV6_Prot}" -m "${Hop_Mode}" "${Int_IPV6_IP}" | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi  
    #保留IPv6路由日志
    echo -e "${Info} 路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

#Nexttrace IPv6 到指定IP路由测试 英文输出，可指定端口(若需修改TCP/ICMP，可修改Nexttrace_Mode代码段)
NT_Specify_IPv6_EN_Mtr(){   
    #IP输入 端口输入
    Int_IPV6
    #删除之前的日志及执行文件 
    AutoTrace_Start
    #下载Nexttrace主程序
    Nexttrace_Ver
    #载入Nexttrace参数
    Nexttrace_Mode
    clear
    #开始测试到指定IPv4路由  
    if [ "${Net_Mode}" = "tcp" ] || [ "${Net_Mode}" = "TCP" ]; then
        echo -e "\nTraceroute to "${Int_IPV6_IP}", Port:"${Int_IPV6_Prot}" (TCP Mode, Max "${Hop_Mode}" Hop, IPv6)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -T -p "${Int_IPV6_Prot}" -m "${Hop_Mode}" "${Int_IPV6_IP}" | tee -a $log
    elif [ "$2" = "icmp" ] || [ "$2" = "ICMP" ]; then
        echo -e "\nTracecroute to "${Int_IPV6_IP}", Port:"${Int_IPV6_Prot}" (ICMP Mode, Max "${Hop_Mode}" Hop, IPv6)" | tee -a $log
        echo -e "============================================================" | tee -a $log
        ${Nexttrace_file} -M -g en -q 1 -n -p "${Int_IPV6_Prot}" -m "${Hop_Mode}" "${Int_IPV6_IP}" | tee -a $log
    else
        echo -e "${Error} 参数错误，请输入 TCP 或 ICMP" && exit 1
    fi  
    #保留IPv6路由日志
    echo -e "${Info} 路由路径已保存在${Green_font_prefix} ${log} ${Font_color_suffix}中，如不需要请自行删除 !" 	
    #删除Nexttrace执行文件
    Nexttrace_Dle       
}

###到指定IP路由测试部分    结束========================================================

#启动菜单区===============================================
#脚本不加参数时的启动菜单
Stand_AutoTrace(){
echo -e " -- AutoTrace 三网回程测试脚本 ${Green_font_prefix}[v${sh_ver}]${Font_color_suffix}  当天运行：$TODAY 次 / 累计运行：$TOTAL 次 --

服务器信息（优先显示IPv4，仅供参考）：
—————————————————————————————————————————————————————————————————————
 ISP      : $ISP_Print
 ASN      : $ASN_Print
 服务商   : $Host_Print
 国家     : $COUNTRY_Print
 地址     : $Location_Print
 IPv4地址 : $IPv4_Print
 IPv6地址 : $IPv6_Print
 IP 性质  : $TYPE_Print
 IP 危险性: $FRAUD_SCORE/100（建议小于60分，分数越高说明 IP 可能存在滥用欺诈行为）

 测试项（TCP Mode，三网回程测试点均为 9 个，包含广东、上海、北京）：
—————————————————————————————————————————————————————————————————————
 ${Yellow_font_prefix}1. 本机 IPv4 三网回程路由 中文 输出 Nexttrace 库（默认）${Font_color_suffix} 
 2. 本机 IPv4 三网回程路由 英文 输出 Nexttrace 库
 ${Yellow_font_prefix}3. 本机 IPv6 三网回程路由 中文 输出 Nexttrace 库${Font_color_suffix} 
 4. 本机 IPv6 三网回程路由 英文 输出 Nexttrace 库
 ${Yellow_font_prefix}5. 本机到指定 IPv4/IPv6 路由 Nexttrace库${Font_color_suffix} 
 6. 退出测试

    " 
    read -e -p " 请输入需要的测试项 [1-6] ( 默认：1 ）：" Stand_AutoTrace_num
    [[ -z "${Stand_AutoTrace_num}" ]] && Stand_AutoTrace_num="1"
    if [[ ${Stand_AutoTrace_num} == "1" ]]; then        
        echo -e "${Info} 您选择的是：本机 IPv4 三网回程路由 中文 输出 Nexttrace库，即将开始测试!  Ctrl+C 取消！
        "
        sleep 4s
        NT_IPv4_IP_CN_Mtr 
    elif [[ ${Stand_AutoTrace_num} == "2" ]]; then 
        echo -e "${Info} 您选择的是：本机 IPv4 三网回程路由 英文 输出 Nexttrace库，即将开始测试!  Ctrl+C 取消！
        "
        sleep 4s
        NT_IPv4_IP_EN_Mtr        
    elif [[ ${Stand_AutoTrace_num} == "3" ]]; then 
        echo -e "${Info} 您选择的是：本机 IPv6 三网回程路由 中文 输出 Nexttrace库，即将开始测试!  Ctrl+C 取消！
        "
        sleep 4s
        NT_IPv6_IP_CN_Mtr
    elif [[ ${Stand_AutoTrace_num} == "4" ]]; then 
        echo -e "${Info} 您选择的是：本机 IPv6 三网回程路由 英文 输出 Nexttrace库，即将开始测试!  Ctrl+C 取消！
        "
        sleep 4s
        NT_IPv6_IP_EN_Mtr 
    elif [[ ${Stand_AutoTrace_num} == "5" ]]; then 
        echo -e "${Info} 您选择的是：本机到指定 IPv4/IPv6 路由 Nexttrace库，即将开始测试!  Ctrl+C 取消！
        "
        sleep 3s
        Specify_IP
    elif [[ ${Stand_AutoTrace_num} == "6" ]]; then 
        echo -e "${Info} 已取消测试 ！" && exit 1
    else
		echo -e "${Error} 请输入正确的数字 [1-6]" && exit 1
	fi
}

#通过脚本参数启动的传递区域
Specify_IP_AutoTrace(){
    Specify_IP
}
#启动菜单区===============================================



#脚本运行区
clear
echo -e "${Info} 脚本正在初始化，请稍等 ！"
check_sys
checkver
IP_Check
check_root
statistics_of_run-times
clear 
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1


#脚本启动入口，通过判断是否传入参数，来判断启动类型,这个代码块放到所有代码之下
Action=$1
[[ -z $1 ]] && Action=Stand
case "$Action" in
	Stand|Specify_IP)
	${Action}_AutoTrace
	;;
	*)
	echo "输入错误 !"
	echo "用法: AutoTrace.sh { Stand | Specify_IP }"
	;;
esac
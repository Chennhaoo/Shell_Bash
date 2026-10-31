#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: Aria2
#	Author: Toyo
#	Blog: https://doub.io/shell-jc4/
#=================================================
sh_ver="2026.10.31_01"
filepath=$(cd "$(dirname "$0")"; pwd)
file_1=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
file="/root/.aria2"
aria2_conf="/root/.aria2/aria2.conf"
aria2_log="/root/.aria2/aria2.log"
Folder="/usr/local/aria2"
aria2c="/usr/bin/aria2c"
Crontab_file="/usr/bin/crontab"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
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

	# 主机架构判断
	ARCH=$(uname -m)
	if [[ "$ARCH" == *"x86_64"* || "$ARCH" == *"amd64"* ]]; then
		# 64-bit kernel
		bit="64bit"
	elif [[ "$ARCH" == *"i386"* || "$ARCH" == *"i686"* ]]; then
		# 32-bit kernel
		bit="32bit"
	elif [[ "$ARCH" == *"aarch64"* || "$ARCH" == *"arm64"* ]]; then
		bit="aarch64"
		echo -e "\nARM 64位 平台"
	elif [[ "$ARCH" == *"arm"* ]]; then
		bit="arm"
		echo -e "\nARM 32位 平台"
	else
		# 未知内核 
		echo -e "${Error} 无法受支持的系统 !" && exit 1
	fi	

	#安装curl
	if ! command -v curl &> /dev/null; then
		echo " 开始安装 curl..."
		Update_SYS_Yuan		
		if [[ ${release} == "centos" ]]; then
			# 在老 CentOS 系统中，有时 curl 的依赖可能冲突，
			# 加上 --skip-broken 可以防止因为个别依赖问题导致整个命令卡死报错
			yum install curl -y --skip-broken
		else
			# Debian/Ubuntu 老系统在极少数情况下可能需要额外依赖组件
			# 加上 -y 并且兜底修复可能损坏的依赖
			apt-get install curl -y
		fi

		# 安装后的二次验证（可选，确保真的安装成功了）
		if ! command -v curl &> /dev/null; then
			echo -e "${Error} curl 安装失败，请检查网络或软件源！" && exit 1
		else
			echo -e "${Info} curl 安装成功！"
		fi
	fi

	#安装nano
	if ! command -v nano &> /dev/null; then
		echo " 开始安装 nano 编辑器..."
		Update_SYS_Yuan
		
		if [[ ${release} == "centos" ]]; then
			# CentOS 6/7/8 安装 nano
			yum install nano -y
		else
			# Debian/Ubuntu 安装 nano
			apt-get install nano -y
		fi
		
		# 二次验证安装结果
		if ! command -v nano &> /dev/null; then
			echo -e "${Error} nano 安装失败，请检查网络或软件源！" && exit 1
		else
			echo -e "${Info} nano 安装成功！"
		fi
	fi
}


#更新软件源
Update_SYS_Yuan(){		
	if [[ ${release} == "centos" ]]; then
		echo -e "${Info} 清空源缓存... "
		yum clean all
		echo -e "${Info} 更新源缓存... "
		yum makecache
	elif [[ ${release} == "ubuntu" ]]; then
		apt-get update
	elif [[ ${release} == "debian" ]]; then 
		if [[ "$(Os_Ver)" == "10" ]]; then
			echo -e "${Info} 您使用的是 Debian 10 系统，开始更新软件源...."
			apt-get --allow-releaseinfo-change update
			apt-get update
		else
			echo -e "${Info} 您使用的是非 Debian 10 系统的 Debian，开始更新软件源...."
			apt-get update	
		fi					
	else
		echo -e "${Error} 您的系统无法探测到" && exit 1
	fi		
	echo -e "${Info} 软件源更新完毕..."
}

#获取操作系统全版本号
Os_Full(){
	[ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

#获取操作系统大版本号
Os_Ver(){
    local main_ver="$( echo $(Os_Full) | grep -oE  "[0-9.]+")"
    printf -- "%s" "${main_ver%%.*}"
}

#脚本版本更新
checkver() {
    running_version=$(sed -n '12s/sh_ver="\(.*\)"/\1/p' "$0")
    curl -L "https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/refs/heads/master/aria2.sh" -o aria2_update.sh && chmod 777 aria2_update.sh
    downloaded_version=$(sed -n '12s/sh_ver="\(.*\)"/\1/p' vpstools_update.sh)
    echo -e "${Info} 本地脚本版本为：${running_version} "
    echo -e "${Info} 最新脚本版本为：${downloaded_version} "
    if [ "$running_version" != "$downloaded_version" ]; then
        echo -e "${Info} 更新脚本从 ${sh_ver} 到 ${downloaded_version}"
        mv aria2_update.sh "$0"
        ./aria2.sh
    else
        echo -e "${Info} 本脚本已是最新，脚本无需更新 ！"
        rm -rf aria2_update.sh*
    fi
}


#Aria2安装检查
check_installed_status(){
	[[ ! -e ${aria2c} ]] && echo -e "${Error} Aria2 没有安装，请检查 !" && exit 1
	[[ ! -e ${aria2_conf} ]] && echo -e "${Error} Aria2 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
}


#定时任务检查
check_crontab_installed_status(){
	# 检查 crontab 命令是否存在
	if ! command -v crontab &> /dev/null; then
		echo -e "${Error} Crontab 没有安装，开始安装..."

		if [[ ${release} == "centos" ]]; then
			# 兼容老版本和新版本 CentOS 的包名
			yum install cronie vixie-cron -y
			
			# 兼容旧系统(SysVinit)和新系统(Systemd)的服务启动
			if command -v systemctl &> /dev/null; then
				systemctl enable --now crond
			else
				service crond start
				chkconfig crond on
			fi
		else
			# Debian/Ubuntu 老系统同样建议先更新源
			apt-get update
			apt-get install cron -y
			
			# 兼容旧系统(SysVinit)和新系统(Systemd)的服务启动
			if command -v systemctl &> /dev/null; then
				systemctl enable --now cron
			else
				service cron start
				update-rc.d cron defaults
			fi
		fi
		
		# 再次检查命令是否存在以确认安装结果
		if ! command -v crontab &> /dev/null; then
			echo -e "${Error} Crontab 安装失败，请检查！" && exit 1
		else
			echo -e "${Info} Crontab 安装成功！"
		fi
	fi
}


#检查aria2c进程
check_pid(){
	PID=$(ps -C "aria2c" -o pid 2>/dev/null | tail -n +2 | tr '\n' ' ')
}


#检查aria2c新版本号
check_new_ver(){
	if ! command -v systemctl &> /dev/null; then
		echo -e "${Info} 您的系统版本过低，为了防止动态库报错，自动为您锁定兼容性最好的 Aria2 [ 1.36.0_20210822 ] 版本"
    	aria2_new_ver="1.36.0_20210822"
	else
		echo -e "${Info} 请输入 Aria2 版本号，格式如：[ 1.37.0_20261029 ]，获取地址：[ https://github.com/Chennhaoo/Aria2-Pro-Core/releases ]"
		read -e -p "默认回车自动获取最新版本号:" aria2_new_ver
		if [[ -z ${aria2_new_ver} ]]; then
			aria2_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/Chennhaoo/Aria2-Pro-Core/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
			if [[ -z ${aria2_new_ver} ]]; then
				echo -e "${Error} Aria2 最新版本获取失败，请手动获取最新版本号[ https://github.com/Chennhaoo/Aria2-Pro-Core/releases ]"
				read -e -p "请输入版本号 [ 格式如 1.37.0_20261029 ] :" aria2_new_ver
				[[ -z "${aria2_new_ver}" ]] && echo "取消..." && exit 1
			else
				echo -e "${Info} 检测到 Aria2 最新版本为 [ ${aria2_new_ver} ]"
			fi
		else
			echo -e "${Info} 即将准备下载 Aria2 版本为 [ ${aria2_new_ver} ]"
		fi
	fi
}

#更新aria2c
check_ver_comparison(){
	aria2_now_ver=$(${aria2c} -v|head -n 1|awk '{print $3}')
	[[ -z ${aria2_now_ver} ]] && echo -e "${Error} 当前版本获取失败 !" && exit 1
	if [[ "${aria2_now_ver}" != "${aria2_new_ver}" ]]; then
		echo -e "${Info} 发现 Aria2 已有新版本 [ ${aria2_new_ver} ](当前版本：${aria2_now_ver})"
		read -e -p "是否更新(会中断当前下载任务，请注意) ? [Y/n] :" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			check_pid
			[[ ! -z $PID ]] && kill -9 ${PID}
			Download_aria2 "update"
			Start_aria2
		fi
	else
		echo -e "${Info} 当前 Aria2 已是最新版本 [ ${aria2_new_ver} ]" && exit 1
	fi
}

#下载aria2c主程序
Download_aria2(){
	update_dl=$1
	cd "/usr/local"
	wget -N --no-check-certificate "https://github.com/Chennhaoo/Aria2-Pro-Core/releases/download/v${aria2_new_ver}/aria2-${aria2_new_ver}-linux-gnu-${bit}-build1.tar.gz"
	Aria2_Name="aria2-${aria2_new_ver}-linux-gnu-${bit}-build1"
	[[ ! -s "${Aria2_Name}.tar.gz" ]] && echo -e "${Error} Aria2 压缩包下载失败 !" && exit 1
	tar -xzvf "${Aria2_Name}.tar.gz"
	[[ ! -e "/usr/local/${Aria2_Name}" ]] && echo -e "${Error} Aria2 解压失败 !" && rm -rf "${Aria2_Name}.tar.gz" && exit 1

	[[ ${update_dl} = "update" ]] && rm -rf "${Folder}"
	mv "/usr/local/${Aria2_Name}" "${Folder}"
	[[ ! -e "${Folder}" ]] && echo -e "${Error} Aria2 文件夹重命名失败 !" && rm -rf "${Aria2_Name}.tar.gz" && rm -rf "/usr/local/${Aria2_Name}" && exit 1
	rm -rf "${Aria2_Name}.tar.gz"
	cd "${Folder}"
	cp aria2c /usr/bin/
	rm -rf "${Folder}"
	[[ ! -e ${aria2c} ]] && echo -e "${Error} Aria2 主程序安装失败！" && rm -rf "${Folder}" && exit 1
	cd /usr/bin/
	chmod +x aria2c
	echo -e "${Info} Aria2 主程序安装完毕！开始下载配置文件..."
}


#下载aria2c设置
Download_aria2_conf(){
	mkdir "${file}" && cd "${file}"
	wget --no-check-certificate -N "https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/other/Aria2/aria2.conf"
	[[ ! -s "aria2.conf" ]] && echo -e "${Error} Aria2 配置文件下载失败 !" && rm -rf "${file}" && exit 1
	wget --no-check-certificate -N "https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/other/Aria2/dht.dat"
	[[ ! -s "dht.dat" ]] && echo -e "${Error} Aria2 DHT文件下载失败 !" && rm -rf "${file}" && exit 1
	echo '' > aria2.session
	sed -i 's/^rpc-secret=DOUBIToyo/rpc-secret='$(date +%s%N | md5sum | head -c 20)'/g' ${aria2_conf}
}


#下载aria2c管理脚本
Service_aria2(){
	if command -v systemctl &> /dev/null; then
    	echo -e "${Info} 启用新系统管理脚本"
    	#直接在本地动态写入标准的 Systemd 服务文件
    	cat > /etc/systemd/system/aria2.service << EOF
[Unit]
Description=Aria2 Service
After=network.target

[Service]
Type=simple
User=root
LimitNOFILE=51200
ExecStart=/usr/bin/aria2c --conf-path=/root/.aria2/aria2.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
		#载入服务并设置开机自启
		systemctl daemon-reload
		systemctl enable aria2
	else
		echo -e "${Info} 启用老系统管理脚本"
		if [[ ${release} = "centos" ]]; then
			if ! wget --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/Sever/aria2_centos -O /etc/init.d/aria2; then
				echo -e "${Error} Aria2服务 管理脚本下载失败 !" && exit 1
			fi
			chmod +x /etc/init.d/aria2
			chkconfig --add aria2
			chkconfig aria2 on
		else
			if ! wget --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/Sever/aria2_debian -O /etc/init.d/aria2; then
				echo -e "${Error} Aria2服务 管理脚本下载失败 !" && exit 1
			fi
			chmod +x /etc/init.d/aria2
			update-rc.d -f aria2 defaults
		fi
	fi
	echo -e "${Info} Aria2服务 管理脚本配置完成 !"
}


#安装aria2c流程
Install_aria2(){
	check_root
	[[ -e ${aria2c} ]] && echo -e "${Error} Aria2 已安装，请检查 !" && exit 1
	check_sys
	echo -e "${Info} 开始下载/安装 主程序..."
	check_new_ver
	Download_aria2
	echo -e "${Info} 开始下载/安装 配置文件..."
	Download_aria2_conf
	echo -e "${Info} 开始下载/安装 服务脚本..."
	Service_aria2
	Read_config
	aria2_RPC_port=${aria2_port}
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	echo -e "${Info} 开始添加 iptables防火墙规则..."
	Add_iptables
	echo -e "${Info} 开始保存 iptables防火墙规则..."
	Save_iptables
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start_aria2
	View_Aria2
}

Start_aria2(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} Aria2 正在运行，请检查 !" && exit 1
	if command -v systemctl &> /dev/null; then
		systemctl start aria2		
	else
		/etc/init.d/aria2 start
	fi
	echo -e "${Info} Aria2 已启动"
}

Stop_aria2(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} Aria2 没有运行，请检查 !" && exit 1
	if command -v systemctl &> /dev/null; then
		systemctl stop aria2
	else	
		/etc/init.d/aria2 stop
	fi
	echo -e "${Info} Aria2 已停止"	
}

Restart_aria2(){
	check_installed_status
	check_pid
	if command -v systemctl &> /dev/null; then
		systemctl restart aria2
	else	
		/etc/init.d/aria2 stop
		/etc/init.d/aria2 start
	fi
	echo -e "${Info} Aria2 已重启"
}


#设置aria2c
Set_aria2(){
	check_installed_status
	echo && echo -e "你要做什么？
 ${Green_font_prefix}1.${Font_color_suffix}  修改 Aria2 RPC密码
 ${Green_font_prefix}2.${Font_color_suffix}  修改 Aria2 RPC端口
 ${Green_font_prefix}3.${Font_color_suffix}  修改 Aria2 文件下载位置
 ${Green_font_prefix}4.${Font_color_suffix}  修改 Aria2 密码+端口+文件下载位置
 ${Green_font_prefix}5.${Font_color_suffix}  手动 打开配置文件修改" && echo
	read -e -p "(默认: 取消):" aria2_modify
	[[ -z "${aria2_modify}" ]] && echo "已取消..." && exit 1
	if [[ ${aria2_modify} == "1" ]]; then
		Set_aria2_RPC_passwd
	elif [[ ${aria2_modify} == "2" ]]; then
		Set_aria2_RPC_port
	elif [[ ${aria2_modify} == "3" ]]; then
		Set_aria2_RPC_dir
	elif [[ ${aria2_modify} == "4" ]]; then
		Set_aria2_RPC_passwd_port_dir
	elif [[ ${aria2_modify} == "5" ]]; then
		Set_aria2_vim_conf
	else
		echo -e "${Error} 请输入正确的数字(1-5)" && exit 1
	fi
}


#修改 Aria2 RPC密码
Set_aria2_RPC_passwd(){
	read_123=$1
	if [[ ${read_123} != "1" ]]; then
		Read_config
	fi
	if [[ -z "${aria2_passwd}" ]]; then
		aria2_passwd_1="空(没有检测到配置，可能手动删除或注释了)"
	else
		aria2_passwd_1=${aria2_passwd}
	fi
	echo -e "请输入要设置的 Aria2 RPC密码(旧密码为：${Green_font_prefix}${aria2_passwd_1}${Font_color_suffix})"
	read -e -p "(默认密码: 随机生成 密码请不要包含等号 = 和井号 #):" aria2_RPC_passwd
	echo
	[[ -z "${aria2_RPC_passwd}" ]] && aria2_RPC_passwd=$(date +%s%N | md5sum | head -c 20)
	if [[ "${aria2_passwd}" != "${aria2_RPC_passwd}" ]]; then
		if [[ -z "${aria2_passwd}" ]]; then
			echo -e "\nrpc-secret=${aria2_RPC_passwd}" >> ${aria2_conf}
			if [[ $? -eq 0 ]];then
				echo -e "${Info} 密码修改成功！新密码为：${Green_font_prefix}${aria2_RPC_passwd}${Font_color_suffix}(因为找不到旧配置参数，所以自动加入配置文件底部)"
				if [[ ${read_123} != "1" ]]; then
					Restart_aria2
				fi
			else 
				echo -e "${Error} 密码修改失败！旧密码为：${Green_font_prefix}${aria2_passwd}${Font_color_suffix}"
			fi
		else
			sed -i 's/^rpc-secret='${aria2_passwd}'/rpc-secret='${aria2_RPC_passwd}'/g' ${aria2_conf}
			if [[ $? -eq 0 ]];then
				echo -e "${Info} 密码修改成功！新密码为：${Green_font_prefix}${aria2_RPC_passwd}${Font_color_suffix}"
				if [[ ${read_123} != "1" ]]; then
					Restart_aria2
				fi
			else 
				echo -e "${Error} 密码修改失败！旧密码为：${Green_font_prefix}${aria2_passwd}${Font_color_suffix}"
			fi
		fi
	else
		echo -e "${Error} 新密码与旧密码一致，取消..."
	fi
}


#修改 Aria2 RPC端口
Set_aria2_RPC_port(){
	read_123=$1
	if [[ ${read_123} != "1" ]]; then
		Read_config
	fi
	if [[ -z "${aria2_port}" ]]; then
		aria2_port_1="空(没有检测到配置，可能手动删除或注释了)"
	else
		aria2_port_1=${aria2_port}
	fi
	echo -e "请输入要设置的 Aria2 RPC端口(旧端口为：${Green_font_prefix}${aria2_port_1}${Font_color_suffix})"
	read -e -p "(默认端口: 6800):" aria2_RPC_port
	echo
	[[ -z "${aria2_RPC_port}" ]] && aria2_RPC_port="6800"
	if [[ "${aria2_port}" != "${aria2_RPC_port}" ]]; then
		if [[ -z "${aria2_port}" ]]; then
			echo -e "\nrpc-listen-port=${aria2_RPC_port}" >> ${aria2_conf}
			if [[ $? -eq 0 ]];then
				echo -e "${Info} 端口修改成功！新端口为：${Green_font_prefix}${aria2_RPC_port}${Font_color_suffix}(因为找不到旧配置参数，所以自动加入配置文件底部)"
				Del_iptables
				Add_iptables
				Save_iptables
				if [[ ${read_123} != "1" ]]; then
					Restart_aria2
				fi
			else 
				echo -e "${Error} 端口修改失败！旧端口为：${Green_font_prefix}${aria2_port}${Font_color_suffix}"
			fi
		else
			sed -i 's/^rpc-listen-port='${aria2_port}'/rpc-listen-port='${aria2_RPC_port}'/g' ${aria2_conf}
			if [[ $? -eq 0 ]];then
				echo -e "${Info} 端口修改成功！新密码为：${Green_font_prefix}${aria2_RPC_port}${Font_color_suffix}"
				Del_iptables
				Add_iptables
				Save_iptables
				if [[ ${read_123} != "1" ]]; then
					Restart_aria2
				fi
			else 
				echo -e "${Error} 端口修改失败！旧密码为：${Green_font_prefix}${aria2_port}${Font_color_suffix}"
			fi
		fi
	else
		echo -e "${Error} 新端口与旧端口一致，取消..."
	fi
}


#修改 Aria2 文件下载位置
Set_aria2_RPC_dir(){
	read_123=$1
	if [[ ${read_123} != "1" ]]; then
		Read_config
	fi
	if [[ -z "${aria2_dir}" ]]; then
		aria2_dir_1="空(没有检测到配置，可能手动删除或注释了)"
	else
		aria2_dir_1=${aria2_dir}
	fi
	echo -e "请输入要设置的 Aria2 文件下载位置(旧位置为：${Green_font_prefix}${aria2_dir_1}${Font_color_suffix})"
	read -e -p "(默认位置: /usr/local/aria2_DL):" aria2_RPC_dir
	[[ -z "${aria2_RPC_dir}" ]] && aria2_RPC_dir="/usr/local/aria2_DL"
	echo
	if [[ -d "${aria2_RPC_dir}" ]]; then
		if [[ "${aria2_dir}" != "${aria2_RPC_dir}" ]]; then
			if [[ -z "${aria2_dir}" ]]; then
				echo -e "\ndir=${aria2_RPC_dir}" >> ${aria2_conf}
				if [[ $? -eq 0 ]];then
					echo -e "${Info} 位置修改成功！新位置为：${Green_font_prefix}${aria2_RPC_dir}${Font_color_suffix}(因为找不到旧配置参数，所以自动加入配置文件底部)"
					if [[ ${read_123} != "1" ]]; then
						Restart_aria2
					fi
				else 
					echo -e "${Error} 位置修改失败！旧位置为：${Green_font_prefix}${aria2_dir}${Font_color_suffix}"
				fi
			else
				aria2_dir_2=$(echo "${aria2_dir}"|sed 's/\//\\\//g')
				aria2_RPC_dir_2=$(echo "${aria2_RPC_dir}"|sed 's/\//\\\//g')
				sed -i 's/^dir='${aria2_dir_2}'/dir='${aria2_RPC_dir_2}'/g' ${aria2_conf}
				if [[ $? -eq 0 ]];then
					echo -e "${Info} 位置修改成功！新位置为：${Green_font_prefix}${aria2_RPC_dir}${Font_color_suffix}"
					if [[ ${read_123} != "1" ]]; then
						Restart_aria2
					fi
				else 
					echo -e "${Error} 位置修改失败！旧位置为：${Green_font_prefix}${aria2_dir}${Font_color_suffix}"
				fi
			fi
		else
			echo -e "${Error} 新位置与旧位置一致，取消..."
		fi
	else
		echo -e "${Error} 新位置文件夹不存在，请检查！新位置为：${Green_font_prefix}${aria2_RPC_dir}${Font_color_suffix}"
	fi
}


#修改 Aria2 密码+端口+文件下载位置
Set_aria2_RPC_passwd_port_dir(){
	Read_config
	Set_aria2_RPC_passwd "1"
	Set_aria2_RPC_port "1"
	Set_aria2_RPC_dir "1"
	Restart_aria2
}


#手动 打开配置文件修改
Set_aria2_vim_conf(){
	Read_config
	aria2_port_old=${aria2_port}
	echo -e "${Tip} 手动修改配置文件须知：
${Green_font_prefix}1.${Font_color_suffix} 配置文件中含有中文注释，如果你的 服务器系统 或 SSH工具 不支持中文显示，将会乱码(请本地编辑)。
${Green_font_prefix}2.${Font_color_suffix} 一会自动打开配置文件后，就可以开始手动编辑文件了。
${Green_font_prefix}3.${Font_color_suffix} 如果要退出并保存文件，那么按 ${Green_font_prefix}Ctrl+X键${Font_color_suffix} 后，输入 ${Green_font_prefix}y${Font_color_suffix} 后，再按一下 ${Green_font_prefix}回车键${Font_color_suffix} 即可。
${Green_font_prefix}4.${Font_color_suffix} 如果要退出并不保存文件，那么按 ${Green_font_prefix}Ctrl+X键${Font_color_suffix} 后，输入 ${Green_font_prefix}n${Font_color_suffix} 即可。
${Green_font_prefix}5.${Font_color_suffix} 如果你想在本地编辑配置文件，那么配置文件位置： ${Green_font_prefix}/root/.aria2/aria2.conf${Font_color_suffix} (注意是隐藏目录) 。" && echo
	read -e -p "如果已经理解 nano 使用方法，请按任意键继续，如要取消请使用 Ctrl+C 。" var
	nano "${aria2_conf}"
	Read_config
	if [[ ${aria2_port_old} != ${aria2_port} ]]; then
		aria2_RPC_port=${aria2_port}
		aria2_port=${aria2_port_old}
		Del_iptables
		Add_iptables
		Save_iptables
	fi
	Restart_aria2
}


#读取配置文件
Read_config(){
	status_type=$1
	if [[ ! -e ${aria2_conf} ]]; then
		if [[ ${status_type} != "un" ]]; then
			echo -e "${Error} Aria2 配置文件不存在 !" && exit 1
		fi
	else
		conf_text=$(cat ${aria2_conf}|grep -v '#')
		aria2_dir=$(echo -e "${conf_text}"|grep "dir="|awk -F "=" '{print $NF}')
		aria2_port=$(echo -e "${conf_text}"|grep "rpc-listen-port="|awk -F "=" '{print $NF}')
		aria2_passwd=$(echo -e "${conf_text}"|grep "rpc-secret="|awk -F "=" '{print $NF}')
	fi
	
}


#读取IP+端口+密码+下载地址配置
View_Aria2(){
	check_installed_status
	Read_config
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP(外网IP检测失败)"
			fi
		fi
	fi
	[[ -z "${aria2_dir}" ]] && aria2_dir="找不到配置参数"
	[[ -z "${aria2_port}" ]] && aria2_port="找不到配置参数"
	[[ -z "${aria2_passwd}" ]] && aria2_passwd="找不到配置参数(或无密码)"
	clear
	echo -e "\nAria2 简单配置信息：\n
 地址\t: ${Green_font_prefix}${ip}${Font_color_suffix}
 端口\t: ${Green_font_prefix}${aria2_port}${Font_color_suffix}
 密码\t: ${Green_font_prefix}${aria2_passwd}${Font_color_suffix}
 目录\t: ${Green_font_prefix}${aria2_dir}${Font_color_suffix}\n"
}


#读取日志
View_Log(){
	[[ ! -e ${aria2_log} ]] && echo -e "${Error} Aria2 日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${aria2_log}${Font_color_suffix} 命令。" && echo
	tail -f ${aria2_log}
}


#定时更新BT服务器
Update_bt_tracker(){
	check_installed_status
	check_crontab_installed_status
	crontab_update_status=$(crontab -l 2>/dev/null | grep "aria2.sh update-bt-tracker")
	if [[ -z "${crontab_update_status}" ]]; then
		echo && echo -e "当前自动更新模式: ${Red_font_prefix}未开启${Font_color_suffix}" && echo
		echo -e "确定要开启 ${Green_font_prefix}Aria2 自动更新 BT-Tracker服务器${Font_color_suffix} 功能吗？(一般情况下会加强BT下载效果)[Y/n]"
		read -e -p "注意：该功能会定时重启 Aria2！(默认: y):" crontab_update_status_ny
		[[ -z "${crontab_update_status_ny}" ]] && crontab_update_status_ny="y"
		if [[ ${crontab_update_status_ny} == [Yy] ]]; then
			crontab_update_start
		else
			echo && echo "	已取消..." && echo
		fi
	else
		echo && echo -e "当前自动更新模式: ${Green_font_prefix}已开启${Font_color_suffix}" && echo
		echo -e "确定要关闭 ${Red_font_prefix}Aria2 自动更新 BT-Tracker服务器${Font_color_suffix} 功能吗？(一般情况下会加强BT下载效果)[y/N]"
		read -e -p "注意：该功能会定时重启 Aria2！(默认: n):" crontab_update_status_ny
		[[ -z "${crontab_update_status_ny}" ]] && crontab_update_status_ny="n"
		if [[ ${crontab_update_status_ny} == [Yy] ]]; then
			crontab_update_stop
		else
			echo && echo "	已取消..." && echo
		fi
	fi
}


#添加自动更新BT服务器
crontab_update_start(){
	crontab -l > "$file_1/crontab.bak" 2>/dev/null || touch "$file_1/crontab.bak"
	sed -i "/aria2.sh update-bt-tracker/d" "$file_1/crontab.bak"
	echo -e "\n0 3 * * 1 /bin/bash $file_1/aria2.sh update-bt-tracker" >> "$file_1/crontab.bak"
	crontab "$file_1/crontab.bak"
	rm -f "$file_1/crontab.bak"
	cron_config=$(crontab -l 2>/dev/null | grep "aria2.sh update-bt-tracker")
	if [[ -z ${cron_config} ]]; then
		echo -e "${Error} Aria2 自动更新 BT-Tracker服务器 开启失败 !" && exit 1
	else
		echo -e "${Info} Aria2 自动更新 BT-Tracker服务器 开启成功 !"
		Update_bt_tracker_cron
	fi
}


#停止自动更新BT服务器
crontab_update_stop(){
    if ! crontab -l &>/dev/null; then
        echo -e "${Info} 系统中未检测到任何定时任务，Aria2自动更新BT-Tracker服务器已处于关闭状态 !"
        return 0
    fi
	crontab -l > "$file_1/crontab.bak" 2>/dev/null
	sed -i "/aria2.sh update-bt-tracker/d" "$file_1/crontab.bak"
    if [[ ! -s "$file_1/crontab.bak" ]]; then
        crontab -r 2>/dev/null
    else
        crontab "$file_1/crontab.bak"
    fi
	rm -f "$file_1/crontab.bak"
	cron_config=$(crontab -l 2>/dev/null | grep "aria2.sh update-bt-tracker")
	if [[ ! -z ${cron_config} ]]; then
		echo -e "${Error} Aria2 自动更新 BT-Tracker服务器 停止失败 !" && exit 1
	else
		echo -e "${Info} Aria2 自动更新 BT-Tracker服务器 停止成功 !"
	fi
}


#BT服务器自动更新程序
Update_bt_tracker_cron(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && Stop_aria2
	bt_tracker_list=$(wget -qO- https://raw.githubusercontent.com/ngosang/trackerslist/refs/heads/master/trackers_all.txt |awk NF|sed ":a;N;s/\n/,/g;ta")
	if [ -z "`grep "bt-tracker" ${aria2_conf}`" ]; then
		sed -i '$a bt-tracker='${bt_tracker_list} "${aria2_conf}"
		echo -e "${Info} 添加成功..."
	else
		sed -i "s@bt-tracker.*@bt-tracker=$bt_tracker_list@g" "${aria2_conf}"
		echo -e "${Info} 更新成功..."
	fi
	Start_aria2
}


#更新
Update_aria2(){
	check_installed_status
	check_new_ver
	check_ver_comparison
}


#卸载
Uninstall_aria2(){
	check_installed_status "un"
	echo "确定要卸载 Aria2 ? (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		if crontab -l &>/dev/null; then
			crontab -l > "$file_1/crontab.bak" 2>/dev/null
			sed -i "/aria2.sh/d" "$file_1/crontab.bak"
			
			# 如果过滤后文件大小为0（代表原先只有这一个定时任务），则直接彻底注销整个 crontab
			if [[ ! -s "$file_1/crontab.bak" ]]; then
				crontab -r 2>/dev/null
			else
				crontab "$file_1/crontab.bak"
			fi
			rm -f "$file_1/crontab.bak"
		fi
		check_pid
		[[ ! -z $PID ]] && kill -9 ${PID} 2>/dev/null
		Read_config "un"
		Del_iptables
		Save_iptables
		rm -rf "${aria2c}"
		rm -rf "${Folder}"
		rm -rf "${file}"
		if command -v systemctl &> /dev/null; then
        	#检查服务是否存在，存在才进行清理
        	if systemctl list-unit-files | grep -q "^aria2.service"; then
				systemctl disable --now aria2 2>/dev/null	
				rm -f /etc/systemd/system/aria2.service
				rm -f /lib/systemd/system/aria2.service
				systemctl daemon-reload
				systemctl reset-failed 2>/dev/null
			else
				echo -e "${Info} 系统中未检测到有效的 aria2.service 服务，跳过此步"
			fi		
		else
			if [[ ${release} = "centos" ]]; then
				chkconfig --del aria2
			else
				update-rc.d -f aria2 remove
			fi
			rm -rf "/etc/init.d/aria2"
		fi
		echo && echo "Aria2 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}


#防火墙
Add_iptables(){
	if command -v iptables &> /dev/null; then
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${aria2_RPC_port} -j ACCEPT
		iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${aria2_RPC_port} -j ACCEPT
	else
		echo -e "${Info} 未安装 iptables ，跳过此步..."
	fi	
}
Del_iptables(){
	if command -v iptables &> /dev/null; then	
		iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${aria2_port} -j ACCEPT
		iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${aria2_port} -j ACCEPT
	else
		echo -e "${Info} 未安装 iptables ，跳过此步..."
	fi
}
Save_iptables(){
	if command -v iptables &> /dev/null; then
		if [[ ${release} == "centos" ]]; then
			service iptables save
		else
			iptables-save > /etc/iptables.up.rules
		fi
	else
		echo -e "${Info} 未安装 iptables ，跳过此步..."
	fi
}
Set_iptables(){
	if command -v iptables &> /dev/null; then
		if [[ ${release} == "centos" ]]; then
			service iptables save
			chkconfig --level 2345 iptables on
		else
			iptables-save > /etc/iptables.up.rules
			echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
			chmod +x /etc/network/if-pre-up.d/iptables
		fi
	else
		echo -e "${Info} 未安装 iptables ，跳过此步..."
	fi
}


#定时任务
action=$1
if [[ "${action}" == "update-bt-tracker" ]]; then
	Update_bt_tracker_cron
else

#菜单
check_root
check_sys

#调试时注释掉版本检查
checkver

clear
echo -e " Aria2 一键安装管理脚本 ${Red_font_prefix}MOD_[v${sh_ver}]${Font_color_suffix}
  -- Toyo | ChennHaoo --

 ${Green_font_prefix} 1.${Font_color_suffix} 安装 Aria2
 ${Green_font_prefix} 2.${Font_color_suffix} 更新 Aria2
 ${Green_font_prefix} 3.${Font_color_suffix} 卸载 Aria2
————————————
 ${Green_font_prefix} 4.${Font_color_suffix} 启动 Aria2
 ${Green_font_prefix} 5.${Font_color_suffix} 停止 Aria2
 ${Green_font_prefix} 6.${Font_color_suffix} 重启 Aria2
————————————
 ${Green_font_prefix} 7.${Font_color_suffix} 修改 配置文件
 ${Green_font_prefix} 8.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix} 9.${Font_color_suffix} 查看 日志信息
 ${Green_font_prefix}10.${Font_color_suffix} 配置 自动更新 BT-Tracker服务器
————————————" && echo
#查询云端版本号
if ! command -v systemctl &> /dev/null; then
	aria2_last_new_ver="1.36.0_20210822"
else
	aria2_last_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/Chennhaoo/Aria2-Pro-Core/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
fi
if [[ -z ${aria2_last_new_ver} ]]; then
	aria2_last_new_ver="获取失败"
fi

#查询本地版本
aria2_now_lost_ver=$(${aria2c} -v 2>/dev/null | head -n 1 | awk '{print $3}')
[[ -z ${aria2_now_lost_ver} ]] && aria2_now_lost_ver="获取失败"

if [[ -e ${aria2c} ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix} / 本机版本号：${Green_font_prefix}${aria2_now_lost_ver}${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix} / 本机版本号：${Green_font_prefix}${aria2_now_lost_ver}${Font_color_suffix}"
	fi
else
	echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo -e " 最新版本号: ${Green_font_prefix} ${aria2_last_new_ver} ${Font_color_suffix}"
echo
read -e -p " 请输入数字 [1-10]:" num
case "$num" in
	1)
	Install_aria2
	;;
	2)
	Update_aria2
	;;
	3)
	Uninstall_aria2
	;;
	4)
	Start_aria2
	;;
	5)
	Stop_aria2
	;;
	6)
	Restart_aria2
	;;
	7)
	Set_aria2
	;;
	8)
	View_Aria2
	;;
	9)
	View_Log
	;;
	10)
	Update_bt_tracker
	;;
	*)
	echo "请输入正确数字 [1-10]"
	;;
esac
fi
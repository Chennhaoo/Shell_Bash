#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: VPS Tools
#	Author: ChennHaoo
#	Blog: https://github.com/Chennhaoo
#=================================================

sh_ver="2026.10.27_03"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
SSH_file="${file}/ssh_port.sh"
AutoTrace_file="${file}/AutoTrace.sh"
BT_Panel="/www/server/panel"
Kern_Ver=$( uname -r )

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#检查当前账号是否为root，主要是后面要装软件
check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

#检查系统以及一些必须得环境配置
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

	#安装curl
	if  [[ "$(command -v curl)" == "" ]]; then
		echo " 开始安装 curl..."
		Update_SYS_Yuan
		if [[ ${release} == "centos" ]]; then
			yum install curl -y
		else
			apt-get install curl -y
		fi
	fi
	
	#变量带入区，用于某些变量转换为文本输出或者需要提前安装的软件
	#显示当前系统版本
	VIRT=$(systemd-detect-virt)
	VIRT=${VIRT^^} || VIRT="UNKNOWN"
	OS_input="$(Os_Full)_${bit}_${VIRT}"

	#开机时间
	OPEN_UPTIME=$(awk '{total=int($1); d=int(total/86400); h=int((total%86400)/3600); m=int((total%3600)/60); printf "%d天 / %d小时 / %d分钟\n", d, h, m}' /proc/uptime)
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

#检查VPS虚拟状态，{	if [ -n "${virt}" -a "${virt}" = "kvm" ]; then;}判断
VPS_Virt(){
	#判断是否安装，判断输出是否为空
	if  [[ "$(command -v virt-what)" == "" ]]; then
		echo " 开始安装 virt-what..."
		Update_SYS_Yuan
		if [[ ${release} == "centos" ]]; then
			yum install virt-what -y
		else
			apt-get install virt-what -y
		fi
		#判断虚拟化
		virt=`virt-what`			
	else
		#判断虚拟化
		virt=`virt-what`
	fi

	#判断是否为物理主机，物理主机virt-what输出为空
	if [[ -z ${virt} ]]; then
		echo "您是物理主机吗 ？[y/N]" && echo
		stty erase '^H' && read -p "(默认: N):" unyn 
		[[ -z "${unyn}" ]] && echo -e "${Error} 系统架构检查失败 !" && exit 1
		if [[ ${unyn} == [Nn] ]]; then
			echo -e "${Error} 系统架构检查失败 !" && exit 1
		elif [[ ${unyn} == [Yy] ]]; then
			virt="物理主机"
		else
			echo -e "${Info} 请正确输入 " && exit 1
		fi
	fi
}


#检查当前机器是否开启BBR
checkbbr_now(){
    local param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ x"${param}" == x"bbr" ]]; then
        bbr_now="已开启 BBR 队列算法"
    else
        bbr_now="注意！未开启 BBR 队列算法"
    fi
}


#脚本版本更新
checkver() {
    running_version=$(sed -n '12s/sh_ver="\(.*\)"/\1/p' "$0")
    curl -L "https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/refs/heads/master/vpstools.sh" -o vpstools_update.sh && chmod 777 vpstools_update.sh
    downloaded_version=$(sed -n '12s/sh_ver="\(.*\)"/\1/p' vpstools_update.sh)
    echo -e "${Info} 本地脚本版本为：${running_version} "
    echo -e "${Info} 最新脚本版本为：${downloaded_version} "
    if [ "$running_version" != "$downloaded_version" ]; then
        echo -e "${Info} 更新脚本从 ${sh_ver} 到 ${downloaded_version}"
        mv vpstools_update.sh "$0"
        ./vpstools.sh
    else
        echo -e "${Info} 本脚本已是最新，脚本无需更新 ！"
        rm -rf vpstools_update.sh*
    fi
}

#安装常用依赖
SYS_Tools(){
	echo -e "${Info} 开始更新软件源...."
	Update_SYS_Yuan
	if [[ ${release} == "centos" ]]; then
		echo -e "${Info} 开始安装常用软件...."
		Centos_yum
	else
		echo -e "${Info} 开始安装常用软件...."
		Debian_apt
	fi
	[[ ! -e "/usr/bin/unzip" ]] && echo -e "${Error} 依赖 unzip(解压压缩包) 安装失败，多半是软件包源的问题，请检查 !" && exit 1
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
	echo "nameserver 1.1.1.1" >> /etc/resolv.conf
	SYS_Time
	if [[ ${release} == "centos" ]]; then
		/etc/init.d/crond restart
		echo -e "${Info} 定时任务服务重启完毕...."
	else
		/etc/init.d/cron restart
		echo -e "${Info} 定时任务服务重启完毕...."
	fi
	echo -e "${Info} 常用软件安装完毕...."
}
Centos_yum(){
	cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
	if [[ $? = 0 ]]; then
		yum install -y unzip crond net-tools git nano ca-certificates curl
	else
		yum install -y unzip crond git nano ca-certificates curl
	fi
}
Debian_apt(){
	cat /etc/issue |grep 9\..*>/dev/null
	if [[ $? = 0 ]]; then
		apt-get install -y unzip cron net-tools git nano ca-certificates curl
	else
		apt-get install -y unzip cron git nano ca-certificates curl
	fi
}



#更新系统时间
SYS_Time(){
    #配置时区为上海时间
    echo -e "${Info} 开始配置时区为上海时间...."
    if command -v timedatectl &> /dev/null; then
        timedatectl set-timezone Asia/Shanghai
        echo -e "${Info} 已配置为上海时区"
    else
        if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
            \cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
            echo -e "${Info} 已修改为上海时区"
        else
            echo -e "${Error} 缺少系统时区文件，请检查系统环境！" && exit 1	
        fi
    fi

    #强制系统锁定为24小时制
    echo -e "${Info} 开始配置系统为 24 小时时间制...."
    if command -v localectl &> /dev/null; then
        # 现代系统标准做法：将时间格式（LC_TIME）单独设置为支持24小时制的区域（如 C.UTF-8 或 zh_CN.UTF-8）
        localectl set-locale LC_TIME=C.UTF-8 2>/dev/null
        echo -e "${Info} 已修改为 24 小时制...."
    else
        # 老旧系统/环境兜底：直接向配置文件写入环境变量
        if [ -f /etc/default/locale ]; then
            # 移除旧的 LC_TIME 设置，防止重复
            sed -i '/LC_TIME/d' /etc/default/locale
            echo "LC_TIME=C.UTF-8" >> /etc/default/locale
        elif [ -f /etc/locale.conf ]; then
            sed -i '/LC_TIME/d' /etc/locale.conf
            echo "LC_TIME=C.UTF-8" >> /etc/locale.conf
        fi
        # 临时在当前脚本上下文中生效
        export LC_TIME=C.UTF-8
    fi

    #同步系统时间
    echo -e "${Info} 开始同步系统时间...."
    if command -v timedatectl &> /dev/null; then
        timedatectl set-ntp true 2>/dev/null
        if command -v chronyc &> /dev/null; then
            chronyc makestep &>/dev/null
        fi
        echo -e "${Info} 对时完成"
    else
        if [[ "$(command -v ntpdate)" == "" ]]; then
            echo -e "${Info} 检测到旧版系统，开始安装 ntpdate ...."
            if [[ ${release} == "centos" ]]; then
                yum -y install ntpdate
            elif [[ ${release} == "debian" || ${release} == "ubuntu" ]]; then    
                apt-get update && apt-get install ntpdate -y
            fi
        fi
        if command -v ntpdate &> /dev/null; then
            ntpdate -u cn.pool.ntp.org
        fi
    fi

    #将时间写入硬件时钟
    hwclock --walthc 2>/dev/null || hwclock -w 2>/dev/null

    #打印当前时间验证效果（临时强制用24小时格式输出展示）
    echo -e "${Info} 系统时间修改完毕，当前24小时制时间为：$(LC_TIME=C.UTF-8 date)"
    echo -e "${Info} 提示：重新登录 SSH 终端后，直接输入 date 命令即可永久显示24小时制。"
}



#更新系统及软件
Update_SYS(){
	echo -e "${Info} 升级前请做好备份，如有内核升级请慎重考虑 ！"
	echo "确定要升级系统软件吗 ？[y/N]" && echo
	stty erase '^H' && read -p "(默认: Y):" unyn
	[[ -z ${unyn} ]] && unyn="y"
	if [[ ${unyn} == [Nn] ]]; then
		echo && echo -e "${Info} 已取消..." && exit 1
	elif [[ ${unyn} == [Yy] ]]; then		
		if [[ ${release} == "centos" ]]; then
			echo -e "${Info} 开始更新软件，请手动确认是否升级 ！"
			Update_SYS_Yuan
			yum update
		else
			echo -e "${Info} 开始更新软件源...."
			Update_SYS_Yuan
			echo -e "${Info} 软件源更新完毕！"
			echo -e "${Info} 开始更新软件，请手动确认是否升级 ！"
			echo -e "${Info} 若更新含有内核、GRUB更新，请务必在后面执行 dist-upgrade，否则可能存在无法启动 ！"
			apt-get upgrade
			echo -e "${Info} 若存在内核、GRUB更新，请同意执行 dist-upgrade 命令！"
			echo "确定要执行 dist-upgrade 命令吗 ？[y/N]" && echo
			stty erase '^H' && read -p "(默认: n):" unyn
			[[ -z ${unyn} ]] && echo "已取消..." 
			if [[ ${unyn} == [Yy] ]]; then	
				apt-get dist-upgrade
			fi
		fi		
		echo -e "${Info} 更新软件及系统完毕，请稍后自行重启 ！"
	else
		echo -e "${Info} 请正确输入 " && exit 1
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

#修改当前用户密码
PASSWORD(){
	clear
echo -e "
 ${Info} 请在下方输入新的密码，密码不会显示，需输入两遍，输入完毕后回车确认！
 如不想修改，请使用 Ctrl+C 取消！或第一次直接回车，第二次随便输入后再回车，两次密码不一样也会取消修改。
———————— 
 "
	passwd
}

#修改Hostname 代码来自：https://www.nodeseek.com/post-189290-1
SYS_Hostname(){
	clear
	CURRENT_HOSTNAME=`hostname`
	echo -e "当前 Hostname: ${CURRENT_HOSTNAME}"
	read -e -p "请输入新的 Hostname：" NEW_HOSTNAME
	echo -e "确定要将 Hostname 更新为${Red_font_prefix} ${NEW_HOSTNAME} ${Font_color_suffix}吗 ？[y/N]" && echo
	stty erase '^H' && read -p "(默认: y):" unyn
	if [[ ${unyn} == [Nn] ]]; then
		echo -e "${Info} 已取消..." && exit 1
	else
		#更新 /etc/hostname 文件
    	echo "${NEW_HOSTNAME}" > /etc/hostname
		#更新 /etc/hosts 文件
		sed -i "s/127.0.1.1\s.*$/127.0.1.1\t${NEW_HOSTNAME}/" /etc/hosts
    	sed -i "s/::1\s.*$/::1\t${NEW_HOSTNAME}/" /etc/hosts
		#使用 hostnamectl 设置主机名
		hostnamectl set-hostname "${NEW_HOSTNAME}"
		echo -e "当前 Hostname 已更新为:${Red_font_prefix} $(hostname) ${Font_color_suffix}，可使用 hostname 命令确认，重启后生效。"
	fi
}





#安装BBR时进行系统判断
Configure_BBR(){
	VPS_Virt
	if [ -n "${virt}" -a "${virt}" = "lxc" ]; then
		echo -e "${Error} BBR 不支持 LXC 虚拟化(不支持更换内核) !" && exit 1
	fi
	if [ -n "${virt}" -a "${virt}" = "openvz" ] || [ -d "/proc/vz" ]; then
		echo -e "${Error} BBR 不支持 OpenVZ 虚拟化(不支持更换内核) !" && exit 1
	fi

	# 检查BBR在内存或内核里是否真正启动成功，启动成功就退出
	if ss -Hopt tcp 2>/dev/null | grep -q "bbr" || lsmod | grep -q "bbr" || sysctl net.ipv4.tcp_available_congestion_control | grep -q "bbr"; then
		echo -e "${Info} 恭喜！您已开启 BBR 队列算法，无需再次设置" && exit 1
	fi	

	BBR_OS_VER
	clear
	if [[ ${release} == "centos" ]]; then
echo -e "您的系统为${Red_font_prefix} $OS_input ${Font_color_suffix}，您当前的内核版本为：${Red_font_prefix}$Kern_Ver${Font_color_suffix}

${Green_font_prefix} [安装前 请注意] ${Font_color_suffix}
1. 安装开启BBR，需要更换内核，存在更换失败等风险(重启后无法开机)，请备份重要文件
2. 本脚本仅支持 KVM 虚拟化系统更换内核，OpenVZ/Docker/LXC 不支持更换内核
3. 本脚本来自于秋水逸冰，https://github.com/teddysun/across
4. 系统识别错误请选择取消
———————————————————————————————  
 是否继续安装 [y/N]" && echo
		stty erase '^H' && read -p "(默认: N):" unyn 
		[[ -z "${unyn}" ]] && echo "已取消..." && exit 1
		if [[ ${unyn} == [Nn] ]]; then
			echo && echo -e "${Info} 已取消..." && exit 1
		elif [[ ${unyn} == [Yy] ]]; then
			clear
			curl -sSO https://raw.githubusercontent.com/teddysun/across/refs/heads/master/bbr.sh && bash bbr.sh
		else
			echo -e "${Info} 请正确输入 " && exit 1
		fi	
	else
echo -e "您的系统为${Red_font_prefix} $OS_input ${Font_color_suffix}，您当前的内核版本为：${Red_font_prefix}$Kern_Ver${Font_color_suffix}

${Green_font_prefix} [安装前 请注意] ${Font_color_suffix}
1. 安装开启BBR，需要更换内核，存在更换失败等风险(重启后无法开机)，请备份重要文件
2. 本脚本仅支持 KVM 虚拟化系统更换内核，OpenVZ/Docker/LXC 不支持更换内核
3. 若使用Debian 9、Ubuntu 18.04 等内核版本在${Green_font_prefix} 4.9.0 ${Font_color_suffix}及其之上的，可直接选择开启BBR而不需更换内核
4. Debian/Ubuntu 更换内核过程中会提示 [ 是否终止卸载内核 ] ，请选择 ${Green_font_prefix} NO ${Font_color_suffix}
5. 本脚本来自于秋水逸冰，https://github.com/teddysun/across
6. 系统识别错误请选择取消		
———————————————————————————————  
 ${Green_font_prefix}1.${Font_color_suffix} 直接开启 BBR
 ${Green_font_prefix}2.${Font_color_suffix} 安装最新版内核并开启 BBR" && echo		
		stty erase '^H' && read -p "(默认: 取消):" bbr_num
		[[ -z "${bbr_num}" ]] && echo "已取消..." && exit 1
		if [[ ${bbr_num} == "1" ]]; then
			Start_BBR
		elif [[ ${bbr_num} == "2" ]]; then
			clear
			curl -sSO https://raw.githubusercontent.com/teddysun/across/refs/heads/master/bbr.sh && bash bbr.sh		
		else
			echo -e "${Error} 请输入正确的数字(1-2)" && exit 1
		fi	
	fi	
}

#KVM开启BBR系统版本判断
BBR_OS_VER(){
	if [[ ${release} == "ubuntu" ]]; then
		[ -n "$(Os_Ver)" -a "$(Os_Ver)" -lt 16 ] && echo -e "${Error}您的系统版本低于 Ubuntu 16 ，无法开启BBR ，请升级系统至最低版本" && exit 1
	elif [[ ${release} == "debian" ]]; then 
		[ -n "$(Os_Ver)" -a "$(Os_Ver)" -lt 8 ] && echo -e "${Error}您的系统版本低于 Debian 8 ，无法开启BBR ，请升级系统至最低版本" && exit 1	
	elif [[ ${release} == "centos" ]]; then
		[ -n "$(Os_Ver)" -a "$(Os_Ver)" -lt 6 ] && echo -e "${Error}您的系统版本低于 Centos 6，无法开启BBR ，请升级系统至最低版本" && exit 1
	else
		echo -e "${Error}您的系统无法判断是否可以开启 BBR ，请访问 https://teddysun.com/489.html 查看" && exit 1
	fi
}


Start_BBR(){
	#检查内核版本
    local kernel_main_ver=$(uname -r | awk -F. '{print $1}')
    local kernel_sub_ver=$(uname -r | awk -F. '{print $2}')
	deb_ver="${kernel_main_ver}.${kernel_sub_ver}"

	if [[ -n "${kernel_main_ver}" && -n "${kernel_sub_ver}" ]]; then
		if [[ ${kernel_main_ver} -gt 4 ]] || [[ ${kernel_main_ver} -eq 4 && ${kernel_sub_ver} -ge 9 ]]; then
			echo -e "${Info} 当前内核版本 [${deb_ver}] 可以直接开启 BBR"
		else
			echo -e "${Error} 当前内核版本 [${deb_ver}] 无法直接开启 BBR，请更新内核！" && exit 1
		fi
	else
		echo -e "${Error} 无法判断当前内核版本" && exit 1
	fi

	#判断是否为Debian13及其以上版本
	if [[ ${release} == "debian" && -n "$(Os_Ver)" && "$(Os_Ver)" -ge 13 ]]; then
		mkdir -p /etc/sysctl.d
        cat << 'EOF' > /etc/sysctl.d/99-bbr.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
		sysctl --system >/dev/null 2>&1
	else
		#其他系统写入BBR
		[ -f /etc/sysctl.conf ] && sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
		[ -f /etc/sysctl.conf ] && sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
		echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
		echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
		sysctl -p >/dev/null 2>&1
	fi
	echo -e "${Info} BBR安装完成"

	#复核BBR是否开启
	if ss -Hopt tcp 2>/dev/null | grep -q "bbr" || lsmod | grep -q "bbr" || sysctl net.ipv4.tcp_available_congestion_control | grep -q "bbr"; then
		echo -e "${Info} 检查完毕，BBR 正在运行中"
	else
		echo -e "${Error} 检查完毕，BBR 开启失败"
	fi
}


#宝塔7.7修改面板
BT_Panel_7.7(){
	clear
	cd "${file}"
	[[ -e ${BT_Panel} ]] && echo -e "${Error} 宝塔面板已安装，请访问https://www.bt.cn/btcode.html查询卸载方法" && exit 1
echo -e "${Green_font_prefix} [安装前 请注意] ${Font_color_suffix}
 本脚本为宝塔迷修改版，详细信息：https://www.baota.me/post-275.html
 安装时会安装3.7版本Python，存在兼容风险。修改版存在一定风险或后门，安装前请备份好重要数据
 请多关注作者网站，如有漏洞更新可通过本脚本中${Green_font_prefix} 升级到宝塔7.7面板 ${Font_color_suffix}命令更新
———————— 
 请问是否需要安装? [y/N]
	 "
	stty erase '^H' && read -p "(默认: y):" unyn 
	if [[ ${unyn} == [Nn] ]]; then
		echo -e "${Info} 已取消..." && exit 1
	else
		echo -e "${Info} 开始安装..."
		if [[ ${release} == "centos" ]]; then
			echo "请确定您是 CentOS 系统吗?[y/N]" && echo
			stty erase '^H' && read -p "(默认: y):" unyn 
			if [[ ${unyn} == [Nn] ]]; then
				echo -e "${Info} 已取消..." && exit 1
			else
				wget -N --no-check-certificate https://down.baota.me/project/bt_panel/script/install_7.7.0_lite.sh && bash install_7.7.0_lite.sh
			fi
		elif [[ ${release} == "debian" ]]; then
			echo "请确定您是 Debian 系统吗？[y/N]" && echo
			stty erase '^H' && read -p "(默认: y):" unyn 
			if [[ ${unyn} == [Nn] ]]; then
				echo -e "${Info} 已取消..." && exit 1
			else
				wget -N --no-check-certificate https://down.baota.me/project/bt_panel/script/install_7.7.0_lite.sh && bash install_7.7.0_lite.sh
			fi
		elif [[ ${release} == "ubuntu" ]]; then
			echo "请确定您是 Ubuntu 系统吗?[y/N]" && echo
			stty erase '^H' && read -p "(默认: y):" unyn 
			if [[ ${unyn} == [Nn] ]]; then
				echo -e "${Info} 已取消..." && exit 1
			else
				wget -N --no-check-certificate https://down.baota.me/project/bt_panel/script/install_7.7.0_lite.sh && bash install_7.7.0_lite.sh
			fi
		else
			echo -e "${Error} 您的系统无法探测到，请访问宝塔官网安装！" && exit 1
		fi		
	fi	
	#删除安装脚本
	rm -rf "${file}/install_7.7.0_lite.sh"
	if [[ -e ${file}/install_7.7.0_lite.sh ]]; then
		echo -e "${Error} 删除文件失败，请手动删除 ${file}/install_7.7.0_lite.sh"
	else	
		echo -e "${Info} 已删除文件"
	fi	
}

#升级到宝塔7.7修改面板（更新）
UPDATE_BT_Panel_7.7(){
	clear
	cd "${file}"
echo -e "${Green_font_prefix} [安装前 请注意] ${Font_color_suffix}
 本脚本为宝塔迷修改版，详细信息：https://www.baota.me/post-275.html
 安装时会安装3.7版本Python，存在兼容风险。修改版存在一定风险或后门，安装前请备份好重要数据
 请多关注作者网站，如有漏洞更新可通过本脚本中${Green_font_prefix} 升级到宝塔7.7面板 ${Font_color_suffix}命令更新
 本脚本仅支持${Red_font_prefix} 由低版本升级或更新7.7版本 ${Font_color_suffix}，不支持降级，降版本请访问：https://www.baota.me/post-275.html
———————— 
 请问是否需要升级? [y/N]
	 "
	stty erase '^H' && read -p "(默认: y):" unyn 
	if [[ ${unyn} == [Nn] ]]; then
		echo -e "${Info} 已取消..." && exit 1
	else
		echo -e "${Info} 开始安装..."
		if [[ ${release} == "centos" ]]; then
			echo "请确定您是 CentOS 系统吗?[y/N]" && echo
			stty erase '^H' && read -p "(默认: y):" unyn 
			if [[ ${unyn} == [Nn] ]]; then
				echo && echo -e "${Info} 已取消..." && exit 1
			else
				wget -N --no-check-certificate https://down.baota.me/project/bt_panel/script/update_7.7.0_lite.sh && bash update_7.7.0_lite.sh
			fi
		elif [[ ${release} == "debian" ]]; then
			echo "请确定您是 Debian 系统吗？[y/N]" && echo
			stty erase '^H' && read -p "(默认: y):" unyn 
			if [[ ${unyn} == [Nn] ]]; then
				echo -e "${Info} 已取消..." && exit 1
			else
				wget -N --no-check-certificate https://down.baota.me/project/bt_panel/script/update_7.7.0_lite.sh && bash update_7.7.0_lite.sh
			fi
		elif [[ ${release} == "ubuntu" ]]; then
			echo "请确定您是 Ubuntu 系统吗?[y/N]" && echo
			stty erase '^H' && read -p "(默认: y):" unyn 
			if [[ ${unyn} == [Nn] ]]; then
				echo -e "${Info} 已取消..." && exit 1
			else
				wget -N --no-check-certificate https://down.baota.me/project/bt_panel/script/update_7.7.0_lite.sh && bash update_7.7.0_lite.sh
			fi
		else
			echo -e "${Error} 您的系统无法探测到，请访问宝塔官网安装！" && exit 1
		fi		
	fi
	#删除安装脚本
	rm -rf "${file}/update_7.7.0_lite.sh"
	if [[ -e ${file}/update_7.7.0_lite.sh ]]; then
		echo -e "${Error} 删除文件失败，请手动删除 ${file}/update_7.7.0_lite.sh"
	else	
		echo -e "${Info} 已删除文件"
	fi		
}


#宝塔第三方云端修改面板
BT_Panel_DSF(){
	clear
	[[ -e ${BT_Panel} ]] && echo -e "${Error} 宝塔面板已安装，请访问https://www.bt.cn/btcode.html查询卸载方法" && exit 1
echo -e "${Green_font_prefix} [安装前 请注意] ${Font_color_suffix}
 本脚本为第三方云端修改版，修改版存在一定风险或后门，安装前请备份好重要数据
 如有漏洞更新可通过本脚本中${Green_font_prefix} 升级/更新 面板 ${Font_color_suffix}命令更新
———————— 
 请问是否需要安装? [y/N]
	 "
	stty erase '^H' && read -p "(默认: y):" unyn 
	if [[ ${unyn} == [Nn] ]]; then
		echo -e "${Info} 已取消..." && exit 1
	else
		echo -e "${Info} 开始安装..."
		curl -sSO https://btmb.anidays.com/install/install_panel.sh && bash install_panel.sh
	fi	
}


#更新宝塔第三方云端修改面板
UPDATE_BT_Panel_DSF(){
	clear
echo -e "${Green_font_prefix} [安装前 请注意] ${Font_color_suffix}
 本脚本为第三方云端修改版，修改版存在一定风险或后门，安装前请备份好重要数据
 如有漏洞更新可通过本脚本中${Green_font_prefix} 升级/更新 面板 ${Font_color_suffix}命令更新
———————— 
 请问是否需要安装? [y/N]
	 "
	stty erase '^H' && read -p "(默认: y):" unyn 
	if [[ ${unyn} == [Nn] ]]; then
		echo -e "${Info} 已取消..." && exit 1
	else
		echo -e "${Info} 开始安装..."
		curl https://btmb.anidays.com/install/update6.sh|bash
	fi	
}


#修改SSH端口
Install_SSHPor(){
	[[ ${release} = "centos" ]] && echo -e "${Error} 本脚本不支持 CentOS系统 !" && exit 1
	echo "确定更改SSH端口吗 ？[y/N]" && echo
	stty erase '^H' && read -p "(默认: y):" unyn 
	if [[ ${unyn} == [Nn] ]]; then
		echo -e "${Info} 已取消..." && exit 1
	else
		if [[ -e ${SSH_file} ]]; then
				rm -rf "${SSH_file}" && echo -e "${Info} 已删除原始脚本，准备重新下载..."
			else
				echo -e "${Error} 没有发现 SSH修改端口脚本，开始下载..."
		fi
		cd "${file}"
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/ssh_port.sh; then
			echo -e "${Error} SSH 修改端口脚本下载失败 !" && exit 1
		else
			echo -e "${Info} SSH 修改端口脚本下载完成 !"
			chmod +x ssh_port.sh
		fi
	fi
	echo -e "${Info} 开始修改..."
	bash "${SSH_file}"
}


#独服硬盘时间检测
DF_Test(){
	cd "${file}"
	clear
	echo -e "${Info} 脚本初始化中 !"
	bash <(wget -qO- git.io/ceshi)
}

#Yabs 测试(跑分)
Install_YB(){
	cd "${file}"
	clear
echo -e " 请选择 Yabs 需要的测试项 
————————————————————————————————————
${Green_font_prefix} 1. ${Font_color_suffix}基本信息+磁盘性能+国际网速+Geekbench 5 跑分（默认）
${Green_font_prefix} 2. ${Font_color_suffix}基本信息+磁盘性能+国际网速+Geekbench 6 跑分
${Green_font_prefix} 3. ${Font_color_suffix}基本信息+磁盘性能+Geekbench 5 跑分
${Green_font_prefix} 4. ${Font_color_suffix}基本信息+磁盘性能+Geekbench 6 跑分
${Green_font_prefix} 5. ${Font_color_suffix}基本信息+Geekbench 6 跑分
${Green_font_prefix} 6. ${Font_color_suffix}基本信息+Geekbench 5 跑分
${Green_font_prefix} 7. ${Font_color_suffix}基本信息+Geekbench 4 跑分
${Green_font_prefix} 8. ${Font_color_suffix}基本信息+磁盘性能
${Green_font_prefix} 9. ${Font_color_suffix}基本信息+国际网速
${Green_font_prefix} 10. ${Font_color_suffix}取消测试

 注： 
 x86主机默认使用Geekbench 4 跑分
 若需Geekbench 6 跑分，内存最好不小于 2 GB
	 "
	read -e -p " 请输入数字 [1-10] ( 默认：1 ）：" yabs_num
	[[ -z "${yabs_num}" ]] && yabs_num="1"
	clear
	if [[ ${yabs_num} == "1" ]]; then
		echo -e "${Info} 您选择的是：基本信息+磁盘性能+国际网速+Geekbench 5 跑分，已开始测试 !
		"	
		sleep 1s
		curl -sL https://yabs.sh | bash -s -- -5
	elif [[ ${yabs_num} == "2" ]]; then
		echo -e "${Info} 您选择的是：基本信息+磁盘性能+国际网速+Geekbench 6 跑分，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s
	elif [[ ${yabs_num} == "3" ]]; then
		echo -e "${Info} 您选择的是：基本信息+磁盘性能+Geekbench 5 跑分，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s -- -i -5
	elif [[ ${yabs_num} == "4" ]]; then
		echo -e "${Info} 您选择的是：基本信息+磁盘性能+Geekbench 6 跑分，已开始测试 !
		"	
		sleep 1s
		curl -sL https://yabs.sh | bash -s -- -i
	elif [[ ${yabs_num} == "5" ]]; then
		echo -e "${Info} 您选择的是：基本信息+Geekbench 6 跑分，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s -- -i -f
	elif [[ ${yabs_num} == "6" ]]; then
		echo -e "${Info} 您选择的是：基本信息+Geekbench 5 跑分，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s -- -i -f -5
	elif [[ ${yabs_num} == "7" ]]; then
		echo -e "${Info} 您选择的是：基本信息+Geekbench 4 跑分，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s -- -i -f -4
	elif [[ ${yabs_num} == "8" ]]; then
		echo -e "${Info} 您选择的是：基本信息+磁盘性能，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s -- -i -g
	elif [[ ${yabs_num} == "9" ]]; then
		echo -e "${Info} 您选择的是：基本信息+国际网速，已开始测试 !
		"	
		sleep 1s	
		curl -sL https://yabs.sh | bash -s -- -f -g
	elif [[ ${yabs_num} == "10" ]]; then
		echo -e "${Info} 已取消测试 ！" && exit 1		
	else
		echo -e "${Error} 请输入正确的数字 [1-10]" && exit 1
	fi
	#测试完毕后删除脚本
	rm -rf "${file}/geekbench_claim.url"
	if [[ -e ${file}/geekbench_claim.url ]]; then
		echo -e "${Error} 删除跑分文件失败，请手动删除 ${file}/geekbench_claim.url"
	else	
		echo -e "${Info} 已删除跑分文件"
	fi	
}


#NodeQuality全能检测脚本
NQ_TEST(){
	clear
	cd "${file}"
	echo -e "${Info} 脚本初始化中 !"
	bash <(curl -sL https://run.NodeQuality.com)
}

#三网回程路由
LY_AutoTrace(){	
	clear
	cd "${file}"
	if [[ -e ${AutoTrace_file} ]]; then
		chmod +x "${AutoTrace_file}"
		bash "${AutoTrace_file}"		
	else	
		echo -e "${Error} 没有发现 AutoTrace 测试脚本，开始下载..."
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/refs/heads/master/AutoTrace.sh; then
			echo -e "${Error} AutoTrace 测试脚本下载失败 !" && exit 1
		else
			echo -e "${Info} AutoTrace 测试脚本下载完成 !"
			chmod +x "${AutoTrace_file}"
			bash "${AutoTrace_file}"
		fi
	fi	
	#测试完毕后删除脚本
	rm -rf "${AutoTrace_file}"
	if [[ -e ${AutoTrace_file} ]]; then
		echo -e "${Error} 删除文件失败，请手动删除 ${AutoTrace_file}"
	else	
		echo -e "${Info} 已删除文件"
	fi
	rm -rf "${file}/AutoTrace_Mtr.log"
	if [[ -e ${file}/AutoTrace_Mtr.log ]]; then
		echo -e "${Error} 删除跑分文件失败，请手动删除 ${file}/AutoTrace_Mtr.log"
	else	
		echo -e "${Info} 已删除跑分文件"
	fi	
}




#显示菜单
clear
echo -e "${Info} 脚本正在初始化，请稍等 ！"
check_sys
check_root
clear
#本地调试时注释掉版本检查
checkver
checkbbr_now
sleep 2s
clear
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
echo -e " VPS工具包 一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Toyo | ChennHaoo --
  
 ${Green_font_prefix} 1.${Font_color_suffix} 安装常用依赖
 ${Green_font_prefix} 2.${Font_color_suffix} 更新软件源（不更新软件）
 ${Green_font_prefix} 3.${Font_color_suffix} 更新系统及软件（慎重）
 ${Green_font_prefix} 4.${Font_color_suffix} 修改系统时间为上海时间
 ${Green_font_prefix} 5.${Font_color_suffix} 修改当前用户登录密码 
 ${Green_font_prefix} 6.${Font_color_suffix} 修改 Hostname 
 ${Green_font_prefix} 7.${Font_color_suffix} 修改 SSH 端口（Centos无法使用）
 ${Green_font_prefix} 8.${Font_color_suffix} 配置 KVM BBR
————————————
 ${Green_font_prefix} 9.${Font_color_suffix} 安装宝塔 7.7 面板（官方修改版，不强制绑定）
 ${Green_font_prefix} 10.${Font_color_suffix} 升级到/更新 宝塔 7.7 面板（官方修改版，不强制绑定，只能由低版本升级）
 ${Green_font_prefix} 11.${Font_color_suffix} 安装宝塔 13.1.0 面板（第三方云端修改版，不强制绑定）
 ${Green_font_prefix} 12.${Font_color_suffix} 升级到/更新 宝塔 13.1.0 面板（第三方修改版，不强制绑定，只能由低版本升级）
————————————
 ${Green_font_prefix} 13.${Font_color_suffix} 独服硬盘时间检测
 ${Green_font_prefix} 14.${Font_color_suffix} Yabs 测试（GB跑分）
 ${Green_font_prefix} 15.${Font_color_suffix} NodeQuality 全能检测脚本
 ${Green_font_prefix} 16.${Font_color_suffix} 三网回程路由

 ${Info} 系统：${Red_font_prefix}$OS_input${Font_color_suffix} / 内核：${Red_font_prefix}$Kern_Ver${Font_color_suffix}
 ${Info} 开机时间：${Red_font_prefix}$OPEN_UPTIME${Font_color_suffix}
 ${Info} BBR状态：${Red_font_prefix}$bbr_now${Font_color_suffix}
 ${Info} 任何时候都可以通过 Ctrl+C 终止命令 !
" && echo
read -e -p " 请输入数字 [1-16]:" num
case "$num" in
	1)
	SYS_Tools
	;;
	2)
	Update_SYS_Yuan
	;;
	3)
	Update_SYS
	;;
	4)
	SYS_Time
	;;
	5)
	PASSWORD
	;;
	6)
	SYS_Hostname
	;;
	7)
	Install_SSHPor
	;;
	8)
	Configure_BBR
	;;
	9)
	BT_Panel_7.7
	;;
	10)
	UPDATE_BT_Panel_7.7
	;;
	11)
	BT_Panel_DSF
	;;
	12)
	UPDATE_BT_Panel_DSF
	;;
	13)
	DF_Test
	;;
	14)
	Install_YB
	;;
	15)
	NQ_TEST
	;;
	16)
	LY_AutoTrace
	;;
	*)
	echo "请输入正确数字 [1-16]"
	;;
esac
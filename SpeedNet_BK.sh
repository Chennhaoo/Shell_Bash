#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: 三网回程快速测试
#	Version: 2023.03.05_01
#	Author: ChennHaoo
#   参考：主机资讯 | www.zhujizixun.com  http://tutu.ovh/bash/returnroute/test.sh
#	Blog: https://github.com/Chennhaoo
#=================================================


echo -e "\n该小工具可以为你检查本服务器到中国北京、上海、广州的[回程网络]类型\n"
read -p "按Enter(回车)开始启动检查..." sdad

iplise=(219.141.136.10 202.106.196.115 211.136.28.231 202.96.199.132 211.95.72.1 211.136.112.50 61.144.56.100 211.95.193.97 120.196.122.69)
iplocal=(北京电信 北京联通 北京移动 上海电信 上海联通 上海移动 广州电信 广州联通 广州移动)
echo "开始安装mtr命令..."
apt install mtr -y
yum -y install mtr
clear
echo -e "\n正在进行TCP回程路由测试,请稍等..."
echo -e "——————————————————————————————\n"
for i in {0..8}; do
	mtr -r --n --tcp ${iplise[i]} > /root/traceroute_testlog

	grep -q "59\.43\." /root/traceroute_testlog
	if [ $? == 0 ];then
		grep -q "202\.97\."  /root/traceroute_testlog
		if [ $? == 0 ];then
			echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;32m电信CN2 GT(AS4809)\033[0m"
		else
			echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;31m电信CN2 GIA(AS4809)\033[0m"
		fi
	else
		grep -q "202\.97\."  /root/traceroute_testlog
		if [ $? == 0 ];then
			grep -q "218\.105\." /root/traceroute_testlog
                        if [ $? == 0 ];then
                            echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;31m联通精品网(AS9929)\033[0m"
			else
			    grep -q "219\.158\." /root/traceroute_testlog
			    if [ $? == 0 ];then
			   	    echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;33m联通169(AS4837)\033[0m"
			    else
				    echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;34m电信163(AS4134)\033[0m"
			    fi
			fi
		else
			grep -q "219\.158\."  /root/traceroute_testlog
			if [ $? == 0 ];then
                            grep -q "218\.105\." /root/traceroute_testlog
                            if [ $? == 0 ];then
                                echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;31m联通精品网(AS9929)\033[0m"
			    else
				echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;33m联通169(AS4837)\033[0m"
			fi

			else
				grep -q "223\.120\."  /root/traceroute_testlog
				if [ $? == 0 ];then
					echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;35m移动CMI(AS9808)\033[0m"
				else
					grep -q "221\.183\." /root/traceroute_testlog
					if [ $? == 0 ];then
						echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;35m移动CMI(AS9808)\033[0m"
					else
                                                grep -q "218\.105\." /root/traceroute_testlog
                                                if [ $? == 0 ];then
                                                    echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;31m联通精品网(AS9929)\033[0m"
                                                else
                                                    grep -q "219\.158\." /root/traceroute_testlog
                                                    if [ $? == 0 ];then
                                                            echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;33m联通169(AS4837)\033[0m"
                                                    else
							    grep -q "219\.158\." /root/traceroute_testlog
	                                                    if [ $? == 0 ];then
                                                                echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:\033[1;34m电信163(AS4134)\033[0m"
							    else
								echo -e "目标:${iplocal[i]}[${iplise[i]}]\t回程线路:其他"
							    fi
                                                    fi
                                                fi

					fi
				fi
			fi
		fi
	fi
echo 
done
rm -f /root/traceroute_testlog
echo -e "\n本脚本测试结果仅供参考\n"

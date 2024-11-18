# Shell_Bash
个人Shell脚本仓库

文件名：bbr-pro.sh <br>
说明：南琴浪大佬的暴力BBR，可自定义内核，只适用于Debian KVM <br>
版本：3.4.5.1<br>
原地址：https://github.com/nanqinlang<br>


文件名：ban_iptables.sh <br>
说明：Doubi大佬的BT SPAM封禁脚本<br>
版本：1.0.10<br>


文件名：ssh_port.sh<br>
说明：Doubi大佬的SSH端口修改脚本<br>
版本：1.0.0<br>


文件名：bbr_CH.sh<br>
说明：Doubi大佬和teddysun的BBR脚本，本人稍作修改<br>
版本：2022.09.17_01<br>


文件名：aria2.sh<br>
说明：Doubi大佬的ARIA2脚本<br>
版本：1.1.10<br>


文件名：vpstools.sh<br>
说明：VPS一键脚本，包含更新源、安装常用软件、BBR安装、时区设置、跑分、测速等<br>
`wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/vpstools.sh && chmod +x vpstools.sh && bash vpstools.sh`

```
 VPS工具包 一键管理脚本 [v2024.11.18_02]
  -- Toyo | ChennHaoo --
  
  1. 安装常用依赖
  2. 更新软件源（不更新软件）
  3. 更新系统及软件（慎重）
  4. 修改系统时间为上海时间
  5. 修改当前用户登录密码 
  6. 修改 Hostname 
————————————
  7. 配置 KVM BBR
  8. 安装宝塔 7.7 面板（修改版，不强制绑定）
  9. 升级到/更新 宝塔 7.7 面板（修改版，不强制绑定，只能由低版本升级）
  10. 修改 SSH 端口（宝塔用户请在面板中修改/Centos无法使用）
————————————
  11. 独服硬盘时间检测
  12. Yabs 测试（GB跑分）
  13. 融合怪脚本测试（全能）
  14. 流媒体解锁检测（全面）
  15. IP质量检测&软件解锁检测
  16. 三网回程路由

 [信息] 当前操作系统：Debian GNU/Linux 12_x64_kvm
 [信息] 当前系统内核：6.1.0-26-cloud-amd64
 [信息] 任何时候都可以通过 Ctrl+C 终止命令 !


 请输入数字 [1-16]:
```


文件名：AutoTrace.sh<br>
说明：测试本机网络信息、IPV4/IPV6 三网回程TCP路由，本机到指定 IPV4/IPV6 TCP路由<br>
`wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh`

```
 -- AutoTrace 三网回程测试脚本 [v2024.10.31_06]  当天运行：55 次 / 累计运行：756 次 --

服务器信息（优先显示IPv4，仅供参考）：
—————————————————————————————————————————————————————————————————————
 ISP      : WIKIHOST
 ASN      : AS215151 WIKIHOST Limited
 服务商   : Invermae Solutions SL
 国家     : Spain
 地址     : ,  ()
 IPv4地址 : 45.131.132.198
 IPv6地址 : 无 IPv6
 IP 性质  : 数据中心
 IP 危险性: 0/100（建议小于60分，分数越高说明 IP 可能存在滥用欺诈行为）

 测试项（TCP Mode，三网回程测试点均为 9 个，包含广东、上海、北京）：
—————————————————————————————————————————————————————————————————————
 1. 本机 IPv4 三网回程路由 中文 输出 Nexttrace 库（默认） 
 2. 本机 IPv4 三网回程路由 英文 输出 Nexttrace 库
 3. 本机 IPv6 三网回程路由 中文 输出 Nexttrace 库 
 4. 本机 IPv6 三网回程路由 英文 输出 Nexttrace 库
 5. 本机到指定 IPv4/IPv6 路由 Nexttrace库 
 6. 退出测试

    
 请输入需要的测试项 [1-6] ( 默认：1 ）：
```



用法 <br>
`wget -N --no-check-certificate https://raw.githubusercontent.com/XXX.sh && chmod +x XXX.sh && bash XXX.sh` <br>


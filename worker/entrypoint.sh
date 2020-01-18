#! /bin/bash
if [[ -z "${AppName}" ]]; then
  echo "应用名未填!程序运行失败,退出"
  exit 1
fi

if [[ -z "${Subcribe_Address}" ]]; then
  echo "订阅地址未填!将不使用订阅地址!"
  Subcribe_Address=""
fi

if [[ "${Subcribe_Address}" == "/" ]];then
  echo "订阅路径不能为根路径,将不使用订阅地址"
  Subcribe_Address=""
fi

if [[ -z "${UUID}" ]]; then
  UUID="$(cat /proc/sys/kernel/random/uuid)"
  echo "UUID未填,将采用随机UUID${UUID}"
fi

if [[ -z "${AlterID}" ]]; then
  AlterID="16"
  echo "AlterID未填,将采用默认AlterID${AlterID}"
fi

if [[ "${V2_Path}" == '/' ]];then
  V2_Path="/FreeV2"
  echo "路径不能为根路径,将采用默认路径${V2_Path}"
fi

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/FreeV2"
  echo "V2路径未填,将采用默认路径${V2_Path}"
fi

if [[ -z "${Anti_Proxy_Path}" ]]; then
  Anti_Proxy_Path="https://www.baidu.com"
  echo "反代理路径未填,将采用默认路径${Anti_Proxy_Path}"
fi

echo "正在设置时间"
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date -R

SYS_Bit="$(getconf LONG_BIT)"
[[ "$SYS_Bit" == '32' ]] && BitVer='_linux_386.tar.gz'
[[ "$SYS_Bit" == '64' ]] && BitVer='_linux_amd64.tar.gz'
echo "判断为${SYS_Bit}位系统"

echo "正在获取V2ray"
if [ "$VER" = "latest" ]; then
  V_VER=`wget -qO- "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4`
else
  V_VER="v$VER"
fi

echo "正在安装V2ray"
mkdir /v2ray
cd /v2ray
wget --no-check-certificate -qO 'v2ray.zip' "https://github.com/v2ray/v2ray-core/releases/download/$V_VER/v2ray-linux-$SYS_Bit.zip"
unzip -q v2ray.zip
rm -rf v2ray.zip
chmod +x /v2ray/*

echo "正在获取Caddy"
C_VER=`wget -qO- "https://api.github.com/repos/mholt/caddy/releases/latest" | grep 'tag_name' | cut -d\" -f4`
mkdir /caddybin
cd /caddybin
wget --no-check-certificate -qO 'caddy.tar.gz' "https://github.com/mholt/caddy/releases/download/$C_VER/caddy_$C_VER$BitVer"

echo "正在安装Caddy"
tar xvf caddy.tar.gz > /dev/null
rm -rf caddy.tar.gz
chmod +x ./caddy
# cd /root
# mkdir /wwwroot
# cd /wwwroot

# wget --no-check-certificate -qO 'demo.tar.gz' "https://raw.githubusercontent.com/ki8852/v2ray-heroku-undone/master/demo.tar.gz"
# tar xvf demo.tar.gz
# rm -rf demo.tar.gz

echo "开始写入配置文件"

cat <<-EOF > /v2ray/config.json
{
    "log":{
        "loglevel":"warning"
    },
    "inbound":{
        "protocol":"vmess",
        "listen":"127.0.0.1",
        "port":25617,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                }
            ]
        },
        "streamSettings":{
            "network":"ws",
            "wsSettings":{
                "path":"${V2_Path}"
            }
        }
    },
    "outbound":{
        "protocol":"freedom",
        "settings":{
        }
    }
}
EOF

echo "伺服端口:${PORT}"
cat <<-EOF > /caddybin/Caddyfile
:${PORT} {
  gzip
  log stdout
	timeouts none
  proxy / ${Anti_Proxy_Path} 
	proxy ${V2_Path} 127.0.0.1:25617 {
		websocket
		header_upstream -Origin
	}
}
EOF

cat <<-EOF > /v2ray/vmess.json 
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "${AlterID}",
    "net": "ws",
    "type": "none",
    "host": "${AppName}.herokuapp.com",		
    "path": "${V2_Path}",
    "tls": "tls"
}
EOF

echo "程序已经运行"

vmess="vmess://$(cat /v2ray/vmess.json | base64 -w 0)" 
echo "您的Vmess链接是:${vmess}"
# Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0) 
# echo "${Linkbase64}" | tr -d '\n' > /wwwroot/$V2_QR_Path/index.html
# echo -n "${vmess}" | qrencode -s 6 -o /wwwroot/$V2_QR_Path/v2.png

/v2ray/v2ray &
/caddybin/caddy -conf="/caddybin/Caddyfile"
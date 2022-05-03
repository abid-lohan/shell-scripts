#!/bin/sh
# Made by Abid Lohan

# Must packages
apt update
apt install git gcc make build-essential autoconf automake libtool libcurl4-openssl-dev liblua5.3-dev libfuzzy-dev ssdeep gettext pkg-config libpcre3 libpcre3-dev libxml2 libxml2-dev libcurl4 libgeoip-dev libyajl-dev doxygen uuid-dev -y

# nginx
add-apt-repository ppa:ondrej/nginx-mainline -y
apt update
apt install nginx-core nginx-common nginx nginx-full -y

sed -i 's/# deb-src/deb-src/' /etc/apt/sources.list.d/ondrej-ubuntu-nginx-mainline-*.list
apt update; apt install dpkg-dev -y
mkdir -p /usr/local/src/nginx; cd /usr/local/src/nginx; apt source nginx

# ModSecurity
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity/
cd /usr/local/src/ModSecurity/
git submodule init
git submodule update
./build.sh
./configure
make -j1
make install

# ModSecurity-nginx module
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx/
cd /usr/local/src/nginx/nginx-*/
apt build-dep nginx -y
./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx
make modules
cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

# Final configs (change proxy_pass and SecRules)

systemctl enable nginx

cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

load_module modules/ngx_http_modsecurity_module.so;


error_log  /var/log/nginx/error-proxy.debug  debug;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    log_format google escape=json '{"time":$msec,"server":"$nginx_version","HttpRequest":{"requestMethod":"$request_method","requestUrl":"$request_uri","requestSize":$request_length,"status":$status,"responseSize":$bytes_sent,"userAgent":"$http_user_agent","remoteIp":"$remote_addr","remotePort":$remote_port,"serverIp":"$server_addr","referer":"$http_referer","latency":$request_time,"cacheLookup":true,"cacheHit":false,"protocol":"$server_protocol"}}';
    server {
        listen       80;
        server_name  localhost;
        access_log /var/log/nginx/access-proxy.log google;

        location / {
            modsecurity on;
            modsecurity_rules_file "/etc/nginx/rules.conf";

            proxy_pass http://localhost:10001/;
        }
    }
}
EOF

cat > /etc/nginx/rules.conf <<EOF
SecRuleEngine On
SecRequestBodyAccess On
SecRequestBodyLimit 13107200
SecRequestBodyLimitAction ProcessPartial
SecResponseBodyAccess Off
SecResponseBodyMimeType text/plain text/html text/xml
SecAuditEngine RelevantOnly
SecAuditLogParts ABIJDEFHZ
SecAuditLogFormat JSON 
SecAuditLogRelevantStatus "403"
SecComponentSignature "WAF/0.0.1"
SecAuditLog /var/log/nginx/access-audit.log
SecAuditLogType Serial 

SecDefaultAction "phase:1,log,auditlog,deny,status:403"

SecRule ARGS:name "@rx [^\w+\s?'?]" "id:1,phase:1,t:none,log,block,msg:'using name allowlist'"
EOF

systemctl restart nginx
#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 脚本名称：04_setup_haproxy_keepalived_remote.sh
# 适用场景：第一章第 4 步，部署 API Server 高可用入口
# 执行位置：ops 节点
# ==============================================================================

VIP="10.1.1.10"
INTERFACE_NAME="ens160"
VRRP_ID="51"
AUTH_PASS="K8S2026"

configure_lb01() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@lb01 "bash -s" <<EOF
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[lb01 1/5] 安装 haproxy 和 keepalived"
apt-get update -y
apt-get install -y haproxy keepalived

echo "[lb01 2/5] 写入 haproxy.cfg"
cat >/etc/haproxy/haproxy.cfg <<'INNER'
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 10s
    timeout client  1m
    timeout server  1m

frontend k8s_api_frontend
    bind *:6443
    default_backend k8s_api_backend

backend k8s_api_backend
    balance roundrobin
    option tcp-check
    server cp01 cp01:6443 check
    server cp02 cp02:6443 check
    server cp03 cp03:6443 check
INNER

echo "[lb01 3/5] 写入健康检查脚本"
cat >/etc/keepalived/check_haproxy.sh <<'INNER'
#!/usr/bin/env bash
systemctl is-active --quiet haproxy
INNER
chmod +x /etc/keepalived/check_haproxy.sh

echo "[lb01 4/5] 写入 keepalived.conf"
cat >/etc/keepalived/keepalived.conf <<INNER
global_defs {
   router_id LB01
}

vrrp_script chk_haproxy {
   script "/etc/keepalived/check_haproxy.sh"
   interval 2
   weight 10
}

vrrp_instance VI_K8S_API {
    state MASTER
    interface ${INTERFACE_NAME}
    virtual_router_id ${VRRP_ID}
    priority 200
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${AUTH_PASS}
    }

    unicast_src_ip 10.1.1.11
    unicast_peer {
        10.1.1.12
    }

    virtual_ipaddress {
        ${VIP}/24 dev ${INTERFACE_NAME}
    }

    track_script {
        chk_haproxy
    }
}
INNER

echo "[lb01 5/5] 启动 haproxy 和 keepalived"
systemctl enable --now haproxy
systemctl enable --now keepalived
systemctl restart haproxy keepalived

systemctl is-active haproxy
systemctl is-active keepalived
EOF
}

configure_lb02() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@lb02 "bash -s" <<EOF
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[lb02 1/5] 安装 haproxy 和 keepalived"
apt-get update -y
apt-get install -y haproxy keepalived

echo "[lb02 2/5] 写入 haproxy.cfg"
cat >/etc/haproxy/haproxy.cfg <<'INNER'
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 10s
    timeout client  1m
    timeout server  1m

frontend k8s_api_frontend
    bind *:6443
    default_backend k8s_api_backend

backend k8s_api_backend
    balance roundrobin
    option tcp-check
    server cp01 cp01:6443 check
    server cp02 cp02:6443 check
    server cp03 cp03:6443 check
INNER

echo "[lb02 3/5] 写入健康检查脚本"
cat >/etc/keepalived/check_haproxy.sh <<'INNER'
#!/usr/bin/env bash
systemctl is-active --quiet haproxy
INNER
chmod +x /etc/keepalived/check_haproxy.sh

echo "[lb02 4/5] 写入 keepalived.conf"
cat >/etc/keepalived/keepalived.conf <<INNER
global_defs {
   router_id LB02
}

vrrp_script chk_haproxy {
   script "/etc/keepalived/check_haproxy.sh"
   interval 2
   weight 10
}

vrrp_instance VI_K8S_API {
    state BACKUP
    interface ${INTERFACE_NAME}
    virtual_router_id ${VRRP_ID}
    priority 150
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${AUTH_PASS}
    }

    unicast_src_ip 10.1.1.12
    unicast_peer {
        10.1.1.11
    }

    virtual_ipaddress {
        ${VIP}/24 dev ${INTERFACE_NAME}
    }

    track_script {
        chk_haproxy
    }
}
INNER

echo "[lb02 5/5] 启动 haproxy 和 keepalived"
systemctl enable --now haproxy
systemctl enable --now keepalived
systemctl restart haproxy keepalived

systemctl is-active haproxy
systemctl is-active keepalived
EOF
}

main() {
  echo "========================================================="
  echo "开始部署 API Server 高可用入口"
  echo "VIP：${VIP}"
  echo "域名：api.qytk8s.com"
  echo "========================================================="

  echo "[1/2] 配置 lb01"
  configure_lb01

  echo "[2/2] 配置 lb02"
  configure_lb02

  echo "OK: HAProxy + Keepalived 部署完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi

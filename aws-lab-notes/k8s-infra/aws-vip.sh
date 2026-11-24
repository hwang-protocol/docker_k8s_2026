#!/usr/bin/env bash
# keepalived notify_master hook for AWS (installed on lb01/lb02 as /etc/keepalived/aws-vip.sh).
#
# Why: in a VPC, a gratuitous ARP from keepalived is ignored. The VPC only delivers traffic for
# 10.1.1.10 to the ENI that owns it as a secondary private IP. So when this node becomes MASTER,
# it calls EC2 AssignPrivateIpAddresses (AllowReassignment=true) to pull the VIP onto its own ENI.
#
# Credentials come from the instance role k8s-course-lb-vip via IMDSv2; the request is signed
# with curl's built-in --aws-sigv4, so no AWS CLI is needed on the node.
set -euo pipefail
VIP="${VIP:-10.1.1.10}"
IMDS=http://169.254.169.254/latest
log() { logger -t aws-vip "$*"; echo "$*"; }

TOKEN=$(curl -sf -X PUT "$IMDS/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/$1"; }
REGION=$(md placement/region)
MAC=$(md mac)
ENI=$(md "network/interfaces/macs/$MAC/interface-id")
ROLE=$(md iam/security-credentials/)
CREDS=$(md "iam/security-credentials/$ROLE")

for try in 1 2 3; do
  if curl -sf --aws-sigv4 "aws:amz:${REGION}:ec2" \
      --user "$(jq -r .AccessKeyId <<<"$CREDS"):$(jq -r .SecretAccessKey <<<"$CREDS")" \
      -H "X-Amz-Security-Token: $(jq -r .Token <<<"$CREDS")" \
      "https://ec2.${REGION}.amazonaws.com/" \
      --data-urlencode "Action=AssignPrivateIpAddresses" \
      --data-urlencode "Version=2016-11-15" \
      --data-urlencode "NetworkInterfaceId=${ENI}" \
      --data-urlencode "PrivateIpAddress.1=${VIP}" \
      --data-urlencode "AllowReassignment=true" >/dev/null; then
    log "VIP ${VIP} assigned to ${ENI} ($(hostname))"
    exit 0
  fi
  log "assign ${VIP} to ${ENI} failed (try ${try}), retrying"
  sleep 2
done
exit 1

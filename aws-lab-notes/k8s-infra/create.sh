#!/usr/bin/env bash
# Build the docker_k8s_2026 K8s course topology on AWS (Tokyo).
# Re-runnable: every resource is looked up by its Name tag first and only created if missing.
#
#   VPC 10.1.1.0/24 (same addressing as the course), 1 public subnet in ap-northeast-1c
#   12 EC2 nodes with the course's fixed private IPs (workers moved .1-.4 -> .21-.24, AWS reserves .0-.3)
#   Route 53 private zone qytk8s.com + DHCP search domain, so `ssh root@cp01` works like in the course
#   IAM role for lb01/lb02 so keepalived can move the VIP 10.1.1.10 between their ENIs
#
# Usage (Git Bash):  bash aws-lab-notes/k8s-infra/create.sh
set -euo pipefail
export MSYS_NO_PATHCONV=1 AWS_PAGER=""

REGION=ap-northeast-1
AZ=ap-northeast-1c
AMI=ami-0146cfc901859a3e4            # Ubuntu 24.04 (noble) 20261120
KEY_NAME=k8s-lab-key                 # = ~/.ssh/ec2_vpn_key, login user ubuntu
ROOT_PUB="$(cat ~/.ssh/k8s_course_root.pub)"   # course-internal root key (ops -> all nodes)
# ec2-tokyo jump host public IP, read from local ~/.ssh/config (kept out of the repo)
JUMP_IP="${JUMP_IP:-$(awk '/^Host ec2-tokyo$/{f=1;next} f&&/HostName/{print $2;exit}' ~/.ssh/config)}"
[[ -n "$JUMP_IP" ]] || { echo "JUMP_IP not set and not found in ~/.ssh/config (Host ec2-tokyo)"; exit 1; }
JUMP_CIDR="${JUMP_IP}/32"
P=k8s-course
TAGS="Key=Project,Value=${P}"
aws() { command aws --region "$REGION" "$@"; }

# name  ip  type  root_gb  data_gb  role
NODES="
ops       10.1.1.201 t3.small  30 0  ops
harbor    10.1.1.203 t3.medium 50 0  infra
git       10.1.1.202 t3.medium 30 0  infra
lb01      10.1.1.11  t3.small  16 0  lb
lb02      10.1.1.12  t3.small  16 0  lb
cp01      10.1.1.101 t3.medium 30 0  k8s
cp02      10.1.1.102 t3.medium 30 0  k8s
cp03      10.1.1.103 t3.medium 30 0  k8s
wk-app01  10.1.1.21  t3.large  30 30 k8s
wk-app02  10.1.1.22  t3.large  30 30 k8s
wk-edge01 10.1.1.23  t3.large  30 30 k8s
wk-obs01  10.1.1.24  t3.large  30 30 k8s
"

tagspec() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=${P}}]"; }
find_id() { # type name query
  aws ec2 "describe-$1" --filters "Name=tag:Name,Values=$2" "Name=tag:Project,Values=${P}" --query "$3" --output text | grep -v None | head -1 || true
}

echo "== VPC / subnet / IGW / routes"
VPC=$(find_id vpcs ${P}-vpc "Vpcs[0].VpcId")
if [[ -z "$VPC" ]]; then
  VPC=$(aws ec2 create-vpc --cidr-block 10.1.1.0/24 --tag-specifications "$(tagspec vpc ${P}-vpc)" --query Vpc.VpcId --output text)
  aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-support
  aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames
fi
SUBNET=$(find_id subnets ${P}-subnet "Subnets[0].SubnetId")
if [[ -z "$SUBNET" ]]; then
  SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.1.1.0/24 --availability-zone $AZ \
    --tag-specifications "$(tagspec subnet ${P}-subnet)" --query Subnet.SubnetId --output text)
  aws ec2 modify-subnet-attribute --subnet-id "$SUBNET" --map-public-ip-on-launch
fi
IGW=$(find_id internet-gateways ${P}-igw "InternetGateways[0].InternetGatewayId")
if [[ -z "$IGW" ]]; then
  IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(tagspec internet-gateway ${P}-igw)" --query InternetGateway.InternetGatewayId --output text)
  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"
fi
RTB=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" "Name=association.main,Values=true" --query "RouteTables[0].RouteTableId" --output text)
aws ec2 create-route --route-table-id "$RTB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW" >/dev/null 2>&1 || true

echo "== Route 53 private zone qytk8s.com + DHCP search domain"
ZONE=$(aws route53 list-hosted-zones-by-name --dns-name qytk8s.com --query "HostedZones[?Name=='qytk8s.com.' && Config.PrivateZone].Id | [0]" --output text | sed 's#/hostedzone/##')
if [[ -z "$ZONE" || "$ZONE" == None ]]; then
  ZONE=$(aws route53 create-hosted-zone --name qytk8s.com --caller-reference "${P}-$(date +%s)" \
    --vpc VPCRegion=$REGION,VPCId="$VPC" --hosted-zone-config Comment="${P} lab",PrivateZone=true \
    --query HostedZone.Id --output text | sed 's#/hostedzone/##')
fi
DHCP=$(find_id dhcp-options ${P}-dhcp "DhcpOptions[0].DhcpOptionsId")
if [[ -z "$DHCP" ]]; then
  DHCP=$(aws ec2 create-dhcp-options --dhcp-configurations "Key=domain-name,Values=qytk8s.com" "Key=domain-name-servers,Values=AmazonProvidedDNS" \
    --tag-specifications "$(tagspec dhcp-options ${P}-dhcp)" --query DhcpOptions.DhcpOptionsId --output text)
fi
aws ec2 associate-dhcp-options --dhcp-options-id "$DHCP" --vpc-id "$VPC"

CHANGES=""
add_a() { CHANGES+="{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$1.qytk8s.com\",\"Type\":\"A\",\"TTL\":60,\"ResourceRecords\":[{\"Value\":\"$2\"}]}},"; }
while read -r name ip _; do [[ -n "$name" ]] && add_a "$name" "$ip"; done <<<"$NODES"
add_a api 10.1.1.10
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE" --change-batch "{\"Changes\":[${CHANGES%,}]}" >/dev/null

echo "== Security groups"
SG=$(find_id security-groups ${P}-sg "SecurityGroups[0].GroupId")
if [[ -z "$SG" ]]; then
  SG=$(aws ec2 create-security-group --group-name ${P}-sg --description "${P} all nodes" --vpc-id "$VPC" \
    --tag-specifications "$(tagspec security-group ${P}-sg)" --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG" --ip-permissions \
    "IpProtocol=-1,UserIdGroupPairs=[{GroupId=$SG}]" \
    "IpProtocol=-1,IpRanges=[{CidrIp=10.1.1.0/24},{CidrIp=10.244.0.0/16,Description=pod-cidr}]" >/dev/null
fi
SG_OPS=$(find_id security-groups ${P}-ops-ssh "SecurityGroups[0].GroupId")
if [[ -z "$SG_OPS" ]]; then
  SG_OPS=$(aws ec2 create-security-group --group-name ${P}-ops-ssh --description "SSH to ops from ec2-tokyo jump" --vpc-id "$VPC" \
    --tag-specifications "$(tagspec security-group ${P}-ops-ssh)" --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG_OPS" --protocol tcp --port 22 --cidr $JUMP_CIDR >/dev/null
fi

echo "== IAM role for keepalived VIP failover (lb01/lb02)"
ROLE=${P}-lb-vip
if ! command aws iam get-role --role-name $ROLE >/dev/null 2>&1; then
  command aws iam create-role --role-name $ROLE --tags $TAGS --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  command aws iam put-role-policy --role-name $ROLE --policy-name vip-move --policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["ec2:AssignPrivateIpAddresses","ec2:UnassignPrivateIpAddresses","ec2:DescribeNetworkInterfaces","ec2:DescribeInstances"],"Resource":"*"}]}'
  command aws iam create-instance-profile --instance-profile-name $ROLE >/dev/null
  command aws iam add-role-to-instance-profile --instance-profile-name $ROLE --role-name $ROLE
  sleep 15   # instance profile propagation
fi

echo "== Instances"
while read -r name ip type root data role; do
  [[ -z "$name" ]] && continue
  existing=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${P}-${name}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId" --output text)
  if [[ -n "$existing" ]]; then echo "  $name exists ($existing)"; continue; fi
  bdm="[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$root,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}"
  [[ "$data" != 0 ]] && bdm+=",{\"DeviceName\":\"/dev/sdb\",\"Ebs\":{\"VolumeSize\":$data,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}"
  bdm+="]"
  sgs="$SG"; [[ "$role" == ops ]] && sgs="$SG $SG_OPS"
  extra=(); [[ "$role" == lb ]] && extra=(--iam-instance-profile Name=$ROLE)
  userdata=$(cat <<EOF
#cloud-config
hostname: ${name}
fqdn: ${name}.qytk8s.com
preserve_hostname: false
disable_root: false
runcmd:
  - mkdir -p /root/.ssh && chmod 700 /root/.ssh
  - echo '${ROOT_PUB}' > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
EOF
)
  id=$(aws ec2 run-instances --image-id $AMI --instance-type "$type" --key-name $KEY_NAME \
    --subnet-id "$SUBNET" --private-ip-address "$ip" --security-group-ids $sgs \
    --credit-specification CpuCredits=standard --block-device-mappings "$bdm" "${extra[@]}" \
    --user-data "$userdata" --metadata-options HttpTokens=required,HttpPutResponseHopLimit=2 \
    --tag-specifications "$(tagspec instance ${P}-${name})" "$(tagspec volume ${P}-${name})" \
    --query "Instances[0].InstanceId" --output text)
  echo "  $name -> $id ($ip, $type)"
done <<<"$NODES"

echo "== Wait for all nodes running"
aws ec2 wait instance-running --filters "Name=tag:Project,Values=${P}" "Name=instance-state-name,Values=pending,running"

echo "== Disable source/dest check on K8s nodes (pod traffic)"
for id in $(aws ec2 describe-instances --filters "Name=tag:Project,Values=${P}" "Name=tag:Name,Values=${P}-cp*,${P}-wk-*" \
    "Name=instance-state-name,Values=pending,running" --query "Reservations[].Instances[].InstanceId" --output text); do
  aws ec2 modify-instance-attribute --instance-id "$id" --no-source-dest-check
done

echo "== Elastic IP for ops (stable SSH target)"
OPS_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${P}-ops" "Name=instance-state-name,Values=pending,running,stopped" --query "Reservations[0].Instances[0].InstanceId" --output text)
EIP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=${P}-ops-eip" --query "Addresses[0].AllocationId" --output text)
if [[ "$EIP" == None ]]; then
  EIP=$(aws ec2 allocate-address --domain vpc --tag-specifications "$(tagspec elastic-ip ${P}-ops-eip)" --query AllocationId --output text)
fi
aws ec2 wait instance-running --instance-ids "$OPS_ID"
aws ec2 associate-address --allocation-id "$EIP" --instance-id "$OPS_ID" >/dev/null
echo "ops EIP: $(aws ec2 describe-addresses --allocation-ids "$EIP" --query 'Addresses[0].PublicIp' --output text)"
echo "VPC=$VPC SUBNET=$SUBNET SG=$SG ZONE=$ZONE"

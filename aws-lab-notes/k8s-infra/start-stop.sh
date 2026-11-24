#!/usr/bin/env bash
# Start or stop the whole K8s course cluster (all instances tagged Project=k8s-course).
#   bash aws-lab-notes/k8s-infra/start-stop.sh stop
#   bash aws-lab-notes/k8s-infra/start-stop.sh start
#   bash aws-lab-notes/k8s-infra/start-stop.sh status
# On start, infra nodes (harbor/lb/ops/git) come up first so containerd can pull from Harbor
# and the API VIP exists before the control planes boot.
set -euo pipefail
export MSYS_NO_PATHCONV=1 AWS_PAGER=""
R=ap-northeast-1
ids() { aws ec2 describe-instances --region $R --filters "Name=tag:Project,Values=k8s-course" \
  "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text; }

case "${1:-status}" in
  stop)
    aws ec2 stop-instances --region $R --instance-ids $(ids 'k8s-course-*') --query "StoppingInstances[].CurrentState.Name" --output text ;;
  start)
    infra=$(ids 'k8s-course-harbor,k8s-course-lb0*,k8s-course-ops,k8s-course-git')
    aws ec2 start-instances --region $R --instance-ids $infra >/dev/null
    aws ec2 wait instance-running --region $R --instance-ids $infra
    sleep 45   # let Harbor compose + keepalived settle
    k8s=$(ids 'k8s-course-cp0*,k8s-course-wk-*')
    aws ec2 start-instances --region $R --instance-ids $k8s >/dev/null
    aws ec2 wait instance-running --region $R --instance-ids $k8s
    echo "all running; check with: ssh k8s-ops kubectl get nodes" ;;
  status)
    aws ec2 describe-instances --region $R --filters "Name=tag:Project,Values=k8s-course" \
      --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,State.Name,PrivateIpAddress]" --output table ;;
esac

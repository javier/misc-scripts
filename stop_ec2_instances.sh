#!/usr/bin/env bash
# stop_javier_instances.sh

set -euo pipefail

regions=(eu-west-1 eu-north-1 us-east-1)
NAME_FILTERS='*javier*,*Javier*,*JAVIER*'   # EC2 tag filter is case-sensitive

for r in "${regions[@]}"; do
  echo "### $r"

  # Collect only running instances that match the Name tag
  ids=$(aws ec2 describe-instances \
    --region "$r" \
    --filters "Name=tag:Name,Values=${NAME_FILTERS}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

  if [[ -z "${ids// }" ]]; then
    echo "Nothing to stop in $r."
    continue
  fi

  echo "Stopping: $ids"
  aws ec2 stop-instances --region "$r" --instance-ids $ids >/dev/null
  aws ec2 wait instance-stopped --region "$r" --instance-ids $ids

  # Show a short summary after stopping
  aws ec2 describe-instances \
    --region "$r" \
    --instance-ids $ids \
    --query 'Reservations[].Instances[].{
      Id:InstanceId,
      Name: Tags[?Key==`Name`]|[0].Value,
      State:State.Name,
      Type:InstanceType,
      PrivateIP:PrivateIpAddress,
      PublicIP:PublicIpAddress,
      AZ:Placement.AvailabilityZone
    }' \
    --output table
done

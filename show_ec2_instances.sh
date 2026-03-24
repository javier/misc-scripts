#!/usr/bin/env bash

AWS_PROFILE=dev

if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
  echo "SSO session expired or not logged in. Logging in..."
  aws sso login --profile sso-main
fi

regions=(eu-west-1 eu-north-1 us-east-1)

for r in "${regions[@]}"; do
  echo "### $r"
  aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$r" \
    --filters "Name=tag:Name,Values=*javier*,*Javier*,*JAVIER*" \
    --query "Reservations[].Instances[].{
      Region:'$r',
      Id:InstanceId,
      Name: Tags[?Key==\`Name\`]|[0].Value,
      KeyName:KeyName,
      State:State.Name,
      Type:InstanceType,
      PrivateIP:PrivateIpAddress,
      PublicIP:PublicIpAddress,
      AZ:Placement.AvailabilityZone
    }" \
    --output table
done

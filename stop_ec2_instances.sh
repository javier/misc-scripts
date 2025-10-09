#!/usr/bin/env bash
# stop_javier_instances.sh
# Purpose: Stop every running EC2 instance whose Name tag contains "javier" (any case)
# across the specified regions. Print friendly names before stopping and a summary after.
# Compatibility: Works with macOS default bash 3.2. Do not source this file.

set -euo pipefail

# Regions to scan. Add or remove regions as needed.
regions=(eu-west-1 eu-north-1 us-east-1)

# EC2 tag filters are case sensitive. Include common case variants explicitly.
NAME_FILTERS='*javier*,*Javier*,*JAVIER*'

for r in "${regions[@]}"; do
  echo "### $r"

  # Query only instances that are running and whose Name matches the filters.
  # Return a tab-separated list with two columns: InstanceId and Name tag value.
  pairs="$(aws ec2 describe-instances \
    --region "$r" \
    --filters "Name=tag:Name,Values=${NAME_FILTERS}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`]|[0].Value]' \
    --output text || true)"

  # If the query returned an empty string or whitespace only, there is nothing to stop.
  if [[ -z "${pairs// }" ]]; then
    echo "Nothing to stop in $r."
    continue
  fi

  # Build an array of instance IDs and a human friendly string "Name (ID)".
  ids=()
  pretty=""
  while IFS=$'\t' read -r id name; do
    # Skip lines without an instance ID.
    [[ -z "${id:-}" ]] && continue
    ids+=("$id")
    pretty+="${name:-unknown} (${id}) "
  done <<< "$pairs"

  # Print the exact set of instances that will be stopped.
  echo "Stopping: $pretty"

  # Call stop-instances with the full array of IDs.
  # Use "${ids[@]}" to expand all array elements. Do not use $ids.
  aws ec2 stop-instances --region "$r" --instance-ids "${ids[@]}" >/dev/null

  # Wait until all targeted instances reach the stopped state.
  aws ec2 wait instance-stopped --region "$r" --instance-ids "${ids[@]}"

  # Print a summary table for the instances that were stopped in this region.
  aws ec2 describe-instances \
    --region "$r" \
    --instance-ids "${ids[@]}" \
    --query 'Reservations[].Instances[].{
      AZ:Placement.AvailabilityZone,
      Id:InstanceId,
      Name: Tags[?Key==`Name`]|[0].Value,
      PrivateIP:PrivateIpAddress,
      PublicIP:PublicIpAddress,
      State:State.Name,
      Type:InstanceType
    }' \
    --output table
done

#!/usr/bin/env bash
# enterprise-cluster.sh — manage EC2 instances named "enterprise-…javier…"
# Compatible with macOS Bash 3.2 (no 'mapfile'). Do NOT source this.

# Abort if sourced
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Please run, do not source: bash $0 {status|start|startall|stop|reboot}" >&2
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

ACTION="${1:-status}"
case "$ACTION" in start|startall|stop|status|reboot) ;; *)
  echo "Usage: $0 {status|start|startall|stop|reboot}"; exit 1 ;;
esac

REGIONS=(eu-west-1 eu-north-1 us-east-1)
NAME_FILTERS='*javier*,*Javier*,*JAVIER*'   # EC2 tag filter is case-sensitive
PREFIX='enterprise-'                        # only operate on enterprise-* names
EXTRA_NAME='javier-spx-demo-sender'         # exact match for the SPX sender  ← added

for r in "${REGIONS[@]}"; do
  echo "### $r"

  # Include the exact SPX sender name in the API filter values  ← changed
  output="$(aws ec2 describe-instances \
      --region "$r" \
      --filters "Name=tag:Name,Values=$NAME_FILTERS,$EXTRA_NAME" \
      --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`]|[0].Value, State.Name, PrivateIpAddress, PublicIpAddress, InstanceType, Placement.AvailabilityZone]' \
      --output text || true)"

  [[ -z "${output}" ]] && { echo "No matches."; continue; }

  ids_to_start=()
  ids_to_stop=()
  ids_to_reboot=()

  printf "%-14s %-55s %-12s %-15s %-15s %-12s %-12s\n" "Id" "Name" "State" "PrivateIP" "PublicIP" "Type" "AZ"
  printf "%-14s %-55s %-12s %-15s %-15s %-12s %-12s\n" "--------------" "-------------------------------------------------------" "------------" "---------------" "---------------" "------------" "------------"

  while IFS=$'\t' read -r id name state pip pubip itype az; do
    include=false

    # Include enterprise-* prefix (case-insensitive)
    shopt -s nocasematch
    [[ "$name" == $PREFIX* ]] && include=true
    shopt -u nocasematch

    # Include the exact SPX sender name for status, stop, reboot, and startall  ← changed
    if [[ "$ACTION" == "status" || "$ACTION" == "stop" || "$ACTION" == "reboot" || "$ACTION" == "startall" ]]; then
      if [[ "$name" == "$EXTRA_NAME" ]]; then
        include=true
      fi
    fi

    [[ "$include" == true ]] || continue

    printf "%-14s %-55s %-12s %-15s %-15s %-12s %-12s\n" \
      "$id" "$name" "${state:-"-"}" "${pip:-"-"}" "${pubip:-"-"}" "${itype:-"-"}" "${az:-"-"}"

    case "$ACTION" in
      start|startall) [[ "$state" == "stopped" ]] && ids_to_start+=("$id");;
      stop)           [[ "$state" == "running" ]] && ids_to_stop+=("$id");;
      reboot)         [[ "$state" == "running" ]] && ids_to_reboot+=("$id");;
    esac
  done <<< "$output"

  # Execute
  if [[ "$ACTION" == "start" || "$ACTION" == "startall" ]]; then
    if [[ ${#ids_to_start[@]} -gt 0 ]]; then
      aws ec2 start-instances --region "$r" --instance-ids "${ids[@]:-${ids_to_start[@]}}" >/dev/null
      aws ec2 wait instance-running --region "$r" --instance-ids "${ids_to_start[@]}"
    else
      echo "Nothing to start in $r."
    fi
  elif [[ "$ACTION" == "stop" ]]; then
    if [[ ${#ids_to_stop[@]} -gt 0 ]]; then
      aws ec2 stop-instances --region "$r" --instance-ids "${ids_to_stop[@]}" >/dev/null
      aws ec2 wait instance-stopped --region "$r" --instance-ids "${ids_to_stop[@]}"
    else
      echo "Nothing to stop in $r."
    fi
  elif [[ "$ACTION" == "reboot" ]]; then
    if [[ ${#ids_to_reboot[@]} -gt 0 ]]; then
      aws ec2 reboot-instances --region "$r" --instance-ids "${ids_to_reboot[@]}"
    else
      echo "Nothing to reboot in $r."
    fi
  fi
done

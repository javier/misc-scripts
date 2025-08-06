#!/usr/bin/env bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] && DOT_SOURCED=true || DOT_SOURCED=false

DRYRUN=false
[[ "$1" == "--dryrun" ]] && DRYRUN=true

run_update() {
TIMESTAMP=$(date +"%Y%m%dT%H%M%S")

# Backup folders
BACKUP_DIR="$HOME/temp/hosts"
mkdir -p "$BACKUP_DIR" 

HOSTS_FILE="/private/etc/hosts"
SSH_CONFIG="$HOME/.ssh/config"
HOSTS_BAK="$BACKUP_DIR/hosts.$TIMESTAMP"
SSH_BAK="$BACKUP_DIR/ssh_config.$TIMESTAMP"

echo "Backing up current files..."
sudo cp "$HOSTS_FILE" "$HOSTS_BAK" || { echo "Failed to back up $HOSTS_FILE"; exit 1; }
if [[ ! -f "$SSH_CONFIG" ]]; then
  echo "Warning: $SSH_CONFIG does not exist. Creating an empty one."
  touch "$SSH_CONFIG"
fi
cp "$SSH_CONFIG" "$SSH_BAK" || { echo "Failed to back up $SSH_CONFIG"; exit 1; }

# EC2 instance definitions
NAMES=(
  "enterprise-demo-javier-primary"
  "enterprise-demo-javier-replica"
  "enterprise-replica-stockholm-peered-javier"
  "javier-spx-demo-sender"
  "javier-fosdem-demo"
)

ALIASES=(
  "enterprise-primary"
  "enterprise-replica"
  "enterprise-replica2"
  "spx-sender"
  "clickbench"
)

REGIONS=(
  "eu-west-1"
  "eu-west-1"
  "eu-north-1"
  "eu-west-1"
  "eu-west-1"
)

PEMS=(
  "javier-demos.pem"
  "javier-demos.pem"
  "javier-stockholm.pem"
  "javier-demos.pem"
  "javier-demos.pem"
)

TMP_HOSTS=$(mktemp)
TMP_SSH=$(mktemp)

# Remove existing managed lines from hosts file
grep -vE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+(enterprise-primary|enterprise-replica|enterprise-replica2|spx-sender|clickbench)$" "$HOSTS_FILE" > "$TMP_HOSTS"

# Add marker for managed section
if ! grep -q '# Managed by update-hosts.sh — do not edit below' "$TMP_HOSTS"; then
  echo -e "\n# Managed by update-hosts.sh — do not edit below" >> "$TMP_HOSTS"
fi

# Parse existing ssh config and remove *any* block that matches a managed alias
awk -v aliases="$(IFS=\|; echo "${ALIASES[*]}")" '
  BEGIN { keep = 1 }
  /^Host[ \t]+/ {
    for (i = 1; i <= NF; i++) {
      if ($i ~ aliases) { keep = 0; break }
      else { keep = 1 }
    }
  }
  keep { print }
' "$SSH_CONFIG" > "$TMP_SSH"

# Append SSH managed block marker
if ! grep -q '# Managed by update-hosts.sh — do not edit below manually' "$TMP_SSH"; then
  echo -e "\n# Managed by update-hosts.sh — do not edit below manually" >> "$TMP_SSH"
fi

for ((i = 0; i < ${#NAMES[@]}; i++)); do
  NAME="${NAMES[$i]}"
  ALIAS="${ALIASES[$i]}"
  REGION="${REGIONS[$i]}"
  PEM="${PEMS[$i]}"

  IP=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].PublicIpAddress" \
    --output text)

  if [[ -z "$IP" ]]; then
    IP=$(grep "[[:space:]]$ALIAS\$" "$HOSTS_FILE" | awk '{print $1}')
    if [[ -z "$IP" ]]; then
      echo "Warning: $ALIAS not running and no previous IP found. Skipping."
      continue
    fi
    echo "Retaining previous IP for $ALIAS: $IP"
  else
    echo "Resolved $ALIAS to $IP"
  fi

  # Skip malformed alias or IP
  if [[ -z "$ALIAS" || -z "$IP" ]]; then
    echo "Skipping invalid alias: $ALIAS (IP: $IP)"
    continue
  fi

  # Don't allow commented-out aliases
  case "$ALIAS" in
    \#*) echo "Skipping commented alias: $ALIAS"; continue ;;
  esac

  echo "$IP $ALIAS" >> "$TMP_HOSTS"

 
  DASHED_IP=$(echo "$IP" | sed 's/\./-/g')
  cat >> "$TMP_SSH" <<EOF

Host $ALIAS
    HostName ec2-$DASHED_IP.$REGION.compute.amazonaws.com
    User ubuntu
    IdentityFile ~/.ssh/$PEM
EOF

done

if $DRYRUN; then
  echo
  echo "Dry run mode — no files modified"
  echo
  echo "----- /etc/hosts preview -----"
  cat "$TMP_HOSTS"
  echo
  echo "----- ~/.ssh/config preview -----"
  cat "$TMP_SSH"
else
  echo
  echo "Applying updates..."
  sudo cp "$TMP_HOSTS" "$HOSTS_FILE" || { echo "Failed to update $HOSTS_FILE"; exit 1; }
  cp "$TMP_SSH" "$SSH_CONFIG" || { echo "Failed to update $SSH_CONFIG"; exit 1; }
  echo "Update complete. Backups saved in:"
  echo "  $HOSTS_BAK"
  echo "  $SSH_BAK"
fi

rm -f "$TMP_HOSTS" "$TMP_SSH"
}

run_update || { $DOT_SOURCED && return 1 || exit 1; }

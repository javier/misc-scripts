# update_cluster_volumes.py

Manage EBS volume IOPS and Throughput across AWS regions using saved config profiles.

## Quick start

```bash
# Create a config from current live state
python update_cluster_volumes.py --init --regions eu-west-1,eu-north-1 --pattern javier --env prod

# Check which volumes differ from a config (dry-run, default)
python update_cluster_volumes.py prod

# Show all diffs at once instead of one by one
python update_cluster_volumes.py prod --all

# Actually apply changes (prompts for confirmation)
python update_cluster_volumes.py prod --apply
python update_cluster_volumes.py prod --all --apply
```

## Commands

### Init - create a config file

Discovers EBS volumes matching a name pattern across the given regions and saves their current IOPS and Throughput to a config file.

```bash
python update_cluster_volumes.py --init --regions REGION1,REGION2 --pattern NAME --env ENV
```

- `--regions` - comma-separated AWS regions to scan
- `--pattern` - substring to match against volume Name tags
- `--env` - name for the config file (creates `volumes_<env>.json`)

Example:

```bash
python update_cluster_volumes.py --init --regions eu-west-1,eu-north-1 --pattern javier --env prod
# Creates volumes_prod.json
```

### Update - apply a config to volumes

Compares live volumes against a saved config and updates IOPS/Throughput where they differ.

```bash
python update_cluster_volumes.py <env> [--all] [--apply]
```

- `<env>` - config profile name (reads `volumes_<env>.json`)
- `--all` - show all differing volumes at once, then confirm as a batch
- `--apply` - actually modify volumes (without this flag, it's a dry-run)

By default the script runs in **dry-run mode** and only prints what it would change.

Examples:

```bash
# Dry-run, one by one
python update_cluster_volumes.py dev

# Dry-run, show all at once
python update_cluster_volumes.py dev --all

# Apply changes, confirm one by one
python update_cluster_volumes.py dev --apply

# Apply changes, confirm as a batch
python update_cluster_volumes.py dev --all --apply
```

## Config file format

Config files are JSON with regions as keys. Each region contains a list of volumes with their target IOPS and Throughput:

```json
{
  "eu-west-1": [
    {
      "VolumeId": "vol-0123456789abcdef0",
      "Name": "my-volume",
      "Size": 200,
      "Iops": 16000,
      "Throughput": 1000
    }
  ],
  "eu-north-1": [
    ...
  ]
}
```

Only `Iops` and `Throughput` are used for updates. `Name` and `Size` are kept for reference.

## Typical workflow

1. Init the prod config from current state:
   ```bash
   python update_cluster_volumes.py --init --regions eu-west-1,eu-north-1 --pattern javier --env prod
   ```

2. Copy it to create a dev config and edit the IOPS/Throughput values:
   ```bash
   cp volumes_prod.json volumes_dev.json
   # Edit volumes_dev.json with lower values
   ```

3. Switch to dev config:
   ```bash
   python update_cluster_volumes.py dev --all --apply
   ```

4. Switch back to prod:
   ```bash
   python update_cluster_volumes.py prod --all --apply
   ```

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

## Tiers

Now that all QuestDB data lives on the `/data2` volumes (the primary/replica ZFS
pools were retired, and `/data2` was shrunk to **1000 GB** each in the 2026-07
migration), the two configs express two different intents rather than just
"high vs low everywhere":

| Role | What it is | dev (cheap) | prod (demo) |
| --- | --- | --- | --- |
| **data2** | QuestDB data disks (primary + replica `/data2`, 1000 GB) | 3000 / 125 | 26000 / 2000 |
| **sender** | SPX sender root + store-and-forward buffer | 3000 / 125 | 12000 / 1000 |
| **root** | OS-only boot disks (primary, replica, stockholm `/`) | 3000 / 125 | 6000 / 400 |

- **dev** = gp3 baseline (3000 IOPS / 125 MB/s) on everything: fully operational
  for functional testing, incurs no IOPS/throughput surcharge, cheapest.
- **prod** = performance only where it matters. The `/data2` data disks go
  **very high (26000 IOPS / 2000 MB/s)**; the sender goes high (throughput-bound
  store-and-forward, but below data2); the root disks only go **moderate** since
  they no longer hold data.

> **Note:** these gp3 volumes accept **26000 IOPS / 2000 MB/s** in this
> account/region — higher than the commonly-cited gp3 max of 16000 / 1000, which
> is a documentation figure, not the enforced limit here. Verified by an accepted
> `modify-volume`. Dropping data2 below the original 26000 / 2000 measurably slows
> large scans, so keep prod at these values.

The `Role` field in each entry documents intent; the updater ignores it.

## Config file format

Config files are JSON with regions as keys. Each region contains a list of volumes with their target IOPS and Throughput:

```json
{
  "eu-west-1": [
    {
      "VolumeId": "vol-0123456789abcdef0",
      "Name": "my-volume",
      "Role": "data2 (primary QuestDB data)",
      "Size": 1000,
      "Iops": 26000,
      "Throughput": 2000
    }
  ],
  "eu-north-1": [
    ...
  ]
}
```

Only `Iops` and `Throughput` are used for updates. `Name`, `Role`, and `Size` are kept for reference.

A config that still lists a volume that has since been **deleted** no longer
aborts the run: the volume is reported as `[skip] ... (deleted?)` and ignored.
When you recreate a data disk (e.g. restoring a replica from backup), the new
volume gets a new ID, so re-run `--init` to regenerate the config, or add the
new `VolumeId` by hand.

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

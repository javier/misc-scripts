#!/usr/bin/env python3
"""Update EBS volume IOPS and Throughput to match a target configuration (prod or dev)."""

import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AWS_PROFILE = "dev"


def ensure_sso_login():
    result = subprocess.run(
        ["aws", "sts", "get-caller-identity", "--profile", AWS_PROFILE],
        capture_output=True,
    )
    if result.returncode != 0:
        print("SSO session expired or not logged in. Logging in...")
        subprocess.run(["aws", "sso", "login", "--profile", "sso-main"], check=True)


ensure_sso_login()


def load_config(profile: str) -> dict:
    config_file = SCRIPT_DIR / f"volumes_{profile}.json"
    if not config_file.exists():
        print(f"Error: config file not found: {config_file}")
        sys.exit(1)
    with open(config_file) as f:
        return json.load(f)


def get_current_volumes(region: str, pattern: str = "javier") -> list[dict]:
    result = subprocess.run(
        [
            "aws", "ec2", "describe-volumes",
            "--profile", AWS_PROFILE,
            "--region", region,
            "--filters", f"Name=tag:Name,Values=*{pattern}*",
            "--query",
            "Volumes[].{VolumeId:VolumeId,Name:Tags[?Key==`Name`].Value|[0],Size:Size,Iops:Iops,Throughput:Throughput}",
            "--output", "json",
        ],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def init_config(regions: list[str], pattern: str, env: str):
    """Discover matching volumes and write a new config file."""
    config_file = SCRIPT_DIR / f"volumes_{env}.json"
    if config_file.exists():
        answer = input(f"{config_file.name} already exists. Overwrite? [y/n]: ").strip().lower()
        if answer != "y":
            print("Aborted.")
            return

    config = {}
    total = 0
    for region in regions:
        print(f"Discovering volumes in {region} matching '*{pattern}*'...")
        volumes = get_current_volumes(region, pattern)
        if volumes:
            config[region] = volumes
            for v in volumes:
                print(f"  {v['Name']} ({v['VolumeId']}) - {v['Size']} GiB, {v['Iops']} IOPS, {v['Throughput']} MB/s")
            total += len(volumes)
        else:
            print(f"  No matching volumes found.")

    if not total:
        print("\nNo volumes found. Config file not created.")
        return

    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"\nWrote {total} volume(s) to {config_file.name}")


def get_volumes_by_ids(region: str, volume_ids: list[str]) -> list[dict]:
    """Fetch specific volumes by their IDs."""
    result = subprocess.run(
        [
            "aws", "ec2", "describe-volumes",
            "--profile", AWS_PROFILE,
            "--region", region,
            "--volume-ids", *volume_ids,
            "--query",
            "Volumes[].{VolumeId:VolumeId,Name:Tags[?Key==`Name`].Value|[0],Size:Size,Iops:Iops,Throughput:Throughput}",
            "--output", "json",
        ],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def find_diffs(config: dict) -> list[dict]:
    """Return list of volumes whose IOPS or Throughput differ from the target."""
    diffs = []
    for region in config:
        target_by_id = {v["VolumeId"]: v for v in config[region]}
        if not target_by_id:
            continue
        current_volumes = get_volumes_by_ids(region, list(target_by_id.keys()))
        for vol in current_volumes:
            vid = vol["VolumeId"]
            target = target_by_id[vid]
            if vol["Iops"] != target["Iops"] or vol["Throughput"] != target["Throughput"]:
                diffs.append({
                    "Region": region,
                    "VolumeId": vid,
                    "Name": vol["Name"],
                    "Size": vol["Size"],
                    "CurrentIops": vol["Iops"],
                    "TargetIops": target["Iops"],
                    "CurrentThroughput": vol["Throughput"],
                    "TargetThroughput": target["Throughput"],
                })
    return diffs


def modify_volume(region: str, volume_id: str, iops: int, throughput: int):
    subprocess.run(
        [
            "aws", "ec2", "modify-volume",
            "--profile", AWS_PROFILE,
            "--region", region,
            "--volume-id", volume_id,
            "--iops", str(iops),
            "--throughput", str(throughput),
        ],
        check=True,
    )


def print_diff(d: dict):
    print(f"  Name:       {d['Name']}")
    print(f"  Volume ID:  {d['VolumeId']}")
    print(f"  Region:     {d['Region']}")
    print(f"  Size:       {d['Size']} GiB")
    print(f"  IOPS:       {d['CurrentIops']} -> {d['TargetIops']}")
    print(f"  Throughput: {d['CurrentThroughput']} -> {d['TargetThroughput']}")


def parse_init_args(argv: list[str]) -> dict:
    """Parse --init arguments."""
    result = {"regions": None, "pattern": None, "env": None}
    i = 0
    while i < len(argv):
        if argv[i] == "--regions" and i + 1 < len(argv):
            result["regions"] = argv[i + 1].split(",")
            i += 2
        elif argv[i] == "--pattern" and i + 1 < len(argv):
            result["pattern"] = argv[i + 1]
            i += 2
        elif argv[i] == "--env" and i + 1 < len(argv):
            result["env"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return result


def main():
    if len(sys.argv) < 2:
        print(f"Usage:")
        print(f"  {sys.argv[0]} <env> [--all] [--apply]")
        print(f"  {sys.argv[0]} --init --regions r1,r2 --pattern NAME --env ENV")
        print()
        print("  By default runs in dry-run mode. Pass --apply to actually modify volumes.")
        sys.exit(1)

    if sys.argv[1] == "--init":
        init_args = parse_init_args(sys.argv[2:])
        if not all([init_args["regions"], init_args["pattern"], init_args["env"]]):
            print("--init requires --regions, --pattern, and --env")
            print(f"  Example: {sys.argv[0]} --init --regions eu-west-1,eu-north-1 --pattern javier --env test")
            sys.exit(1)
        init_config(init_args["regions"], init_args["pattern"], init_args["env"])
        return

    profile = sys.argv[1]
    args = set(sys.argv[2:])
    valid_args = {"--all", "--apply"}
    unknown = args - valid_args
    if unknown:
        print(f"Unknown argument(s): {', '.join(unknown)}")
        print(f"Usage: {sys.argv[0]} <env> [--all] [--apply]")
        sys.exit(1)
    mode = "all" if "--all" in args else None
    dry_run = "--apply" not in args

    if dry_run:
        print("[DRY RUN] No changes will be made. Pass --apply to modify volumes.\n")

    config = load_config(profile)

    print(f"Checking volumes against '{profile}' config...")
    diffs = find_diffs(config)

    if not diffs:
        print("All volumes already match the target configuration.")
        return

    print(f"\n{len(diffs)} volume(s) differ from '{profile}' config:\n")

    if mode == "all":
        # Show all diffs, then ask once
        for i, d in enumerate(diffs, 1):
            print(f"[{i}] ---")
            print_diff(d)
            print()

        if dry_run:
            print("[DRY RUN] Would update all of the above.")
        else:
            answer = input("Update all of the above? [y/n/c] (y=yes, n=no, c=cancel): ").strip().lower()
            if answer == "y":
                for d in diffs:
                    print(f"Updating {d['Name']} ({d['VolumeId']})...")
                    try:
                        modify_volume(d["Region"], d["VolumeId"], d["TargetIops"], d["TargetThroughput"])
                        print("  Done.")
                    except subprocess.CalledProcessError as e:
                        print(f"  FAILED: {e}")
                print("\nAll updates complete.")
            else:
                print("Cancelled.")
    else:
        # Ask one by one
        for d in diffs:
            print("---")
            print_diff(d)
            if dry_run:
                print("  [DRY RUN] Would ask to update this volume.\n")
            else:
                answer = input("Update this volume? [y/n/c] (y=yes, n=no, c=cancel): ").strip().lower()
                if answer == "y":
                    print(f"Updating {d['Name']} ({d['VolumeId']})...")
                    try:
                        modify_volume(d["Region"], d["VolumeId"], d["TargetIops"], d["TargetThroughput"])
                        print("  Done.\n")
                    except subprocess.CalledProcessError as e:
                        print(f"  FAILED: {e}\n")
                elif answer == "c":
                    print("Cancelled.")
                    return
                else:
                    print("  Skipped.\n")

    print("Finished.")


if __name__ == "__main__":
    main()

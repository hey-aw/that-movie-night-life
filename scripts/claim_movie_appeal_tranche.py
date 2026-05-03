from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from movie_appeal_tranche_state import (
    DEFAULT_LEASE_HOURS,
    claim_tranche,
    complete_tranche,
    load_queue_manifest,
    read_claim,
    release_tranche,
    tranche_dir_for,
)


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_QUEUE_DIR = ROOT / "Data" / "movie-appeal-tranche-queue"
DEFAULT_WORKER_BATCHES_DIR = ROOT / "Data" / "movie-appeal-worker-batches"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    status = subparsers.add_parser("status")
    status.add_argument("--queue-dir", type=Path, default=DEFAULT_QUEUE_DIR)
    status.add_argument("--tranche-id", type=int)

    claim = subparsers.add_parser("claim")
    claim.add_argument("--queue-dir", type=Path, default=DEFAULT_QUEUE_DIR)
    claim.add_argument("--worker-batches-dir", type=Path, default=DEFAULT_WORKER_BATCHES_DIR)
    claim.add_argument("--tranche-id", type=int, required=True)
    claim.add_argument("--owner", required=True)
    claim.add_argument("--lease-hours", type=int, default=DEFAULT_LEASE_HOURS)
    claim.add_argument("--takeover-expired", action="store_true")

    release = subparsers.add_parser("release")
    release.add_argument("--queue-dir", type=Path, default=DEFAULT_QUEUE_DIR)
    release.add_argument("--tranche-id", type=int, required=True)
    release.add_argument("--owner", required=True)

    complete = subparsers.add_parser("complete")
    complete.add_argument("--queue-dir", type=Path, default=DEFAULT_QUEUE_DIR)
    complete.add_argument("--tranche-id", type=int, required=True)
    complete.add_argument("--owner", required=True)

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "status":
            if args.tranche_id is not None:
                payload = read_claim(tranche_dir_for(args.queue_dir, args.tranche_id))
            else:
                payload = load_queue_manifest(args.queue_dir)
            print(json.dumps(payload, ensure_ascii=False, indent=2))
            return 0

        if args.command == "claim":
            payload = claim_tranche(
                args.queue_dir,
                args.tranche_id,
                args.owner,
                worker_batches_dir=args.worker_batches_dir,
                lease_hours=args.lease_hours,
                takeover_expired=args.takeover_expired,
            )
            print(json.dumps(payload, ensure_ascii=False, indent=2))
            return 0

        if args.command == "release":
            payload = release_tranche(args.queue_dir, args.tranche_id, args.owner)
            print(json.dumps(payload, ensure_ascii=False, indent=2))
            return 0

        if args.command == "complete":
            payload = complete_tranche(args.queue_dir, args.tranche_id, args.owner)
            print(json.dumps(payload, ensure_ascii=False, indent=2))
            return 0
    except ValueError as error:
        print(str(error))
        return 1

    print(f"Unknown command: {args.command}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

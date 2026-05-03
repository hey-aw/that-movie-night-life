from __future__ import annotations

import json
import os
import shutil
import tempfile
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any


PREPARE_LOCK_NAME = ".prepare.lock"
CLAIM_FILE_NAME = "claim.json"
TRANCHE_MANIFEST_NAME = "tranche-manifest.json"
TRANCHE_INDEX_NAME = "tranche-index.json"
WORKER_MANIFEST_NAME = "worker-manifest.json"
MIRROR_STATE_NAME = "mirror-state.json"
DEFAULT_LEASE_HOURS = 4


def utc_now() -> datetime:
    return datetime.now(UTC)


def parse_timestamp(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        delete=False,
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.tmp-",
    ) as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temp_path = Path(handle.name)
    temp_path.replace(path)


def load_json(path: Path, *, default: Any = None) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def load_queue_manifest(queue_dir: Path) -> dict[str, Any]:
    manifest_path = queue_dir / "manifest.json"
    payload = load_json(manifest_path, default={"count": 0, "tranches": []})
    if not isinstance(payload, dict):
        raise ValueError(f"{manifest_path}: expected JSON object")
    payload.setdefault("count", 0)
    payload.setdefault("tranches", [])
    return payload


def write_queue_manifest(queue_dir: Path, payload: dict[str, Any]) -> None:
    payload["tranches"] = sorted(payload.get("tranches", []), key=lambda entry: int(entry["tranche_id"]))
    payload["count"] = len(payload["tranches"])
    atomic_write_json(queue_dir / "manifest.json", payload)


def tranche_dir_for(queue_dir: Path, tranche_id: int) -> Path:
    return queue_dir / f"tranche-{tranche_id:03d}"


def find_tranche_entry(queue_dir: Path, tranche_id: int) -> dict[str, Any] | None:
    manifest = load_queue_manifest(queue_dir)
    for entry in manifest.get("tranches", []):
        if int(entry.get("tranche_id")) == tranche_id:
            return entry
    return None


def replace_tranche_entry(queue_dir: Path, entry: dict[str, Any]) -> None:
    manifest = load_queue_manifest(queue_dir)
    tranches = [current for current in manifest.get("tranches", []) if int(current["tranche_id"]) != int(entry["tranche_id"])]
    tranches.append(entry)
    manifest["tranches"] = tranches
    write_queue_manifest(queue_dir, manifest)


def infer_next_tranche_id(queue_dir: Path) -> int:
    manifest = load_queue_manifest(queue_dir)
    tranches = manifest.get("tranches", [])
    if not tranches:
        return 1
    return max(int(entry["tranche_id"]) for entry in tranches) + 1


def default_claim_payload(tranche_id: int) -> dict[str, Any]:
    return {
        "tranche_id": tranche_id,
        "status": "unclaimed",
        "owner": None,
        "claimed_at": None,
        "expires_at": None,
    }


def read_claim(tranche_dir: Path) -> dict[str, Any]:
    claim_path = tranche_dir / CLAIM_FILE_NAME
    payload = load_json(claim_path, default=None)
    if payload is None:
        tranche_index = load_json(tranche_dir / TRANCHE_INDEX_NAME, default={})
        tranche_id = int(tranche_index.get("tranche_id") or tranche_dir.name.split("-")[-1])
        payload = default_claim_payload(tranche_id)
        atomic_write_json(claim_path, payload)
    if not isinstance(payload, dict):
        raise ValueError(f"{claim_path}: expected JSON object")
    return payload


def claim_is_expired(claim: dict[str, Any], *, now: datetime | None = None) -> bool:
    if claim.get("status") != "claimed":
        return False
    expires_at = parse_timestamp(claim.get("expires_at"))
    if expires_at is None:
        return False
    return expires_at <= (now or utc_now())


def update_tranche_status(queue_dir: Path, tranche_id: int, status: str, *, claim_path: Path | None = None) -> None:
    entry = find_tranche_entry(queue_dir, tranche_id)
    if entry is None:
        return
    updated = dict(entry)
    updated["status"] = status
    if claim_path is not None:
        updated["claim_path"] = str(claim_path)
    replace_tranche_entry(queue_dir, updated)


def init_tranche_claim(tranche_dir: Path, tranche_id: int) -> Path:
    claim_path = tranche_dir / CLAIM_FILE_NAME
    if not claim_path.exists():
        atomic_write_json(claim_path, default_claim_payload(tranche_id))
    return claim_path


def refresh_worker_mirror(tranche_dir: Path, worker_batches_dir: Path, claim: dict[str, Any]) -> None:
    temp_dir = worker_batches_dir.parent / f".{worker_batches_dir.name}.tmp"
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir(parents=True, exist_ok=True)

    for filename in ("seed.json", WORKER_MANIFEST_NAME, TRANCHE_INDEX_NAME, TRANCHE_MANIFEST_NAME, CLAIM_FILE_NAME):
        source = tranche_dir / filename
        if source.exists():
            shutil.copy2(source, temp_dir / filename)

    for batch_path in sorted(tranche_dir.glob("batch-*.json")):
        shutil.copy2(batch_path, temp_dir / batch_path.name)

    atomic_write_json(
        temp_dir / MIRROR_STATE_NAME,
        {
            "tranche_id": claim["tranche_id"],
            "owner": claim.get("owner"),
            "status": claim.get("status"),
            "claimed_at": claim.get("claimed_at"),
            "expires_at": claim.get("expires_at"),
            "source_tranche_path": str(tranche_dir),
        },
    )

    backup_dir = worker_batches_dir.parent / f".{worker_batches_dir.name}.old"
    if backup_dir.exists():
        shutil.rmtree(backup_dir)
    if worker_batches_dir.exists():
        worker_batches_dir.rename(backup_dir)
    temp_dir.rename(worker_batches_dir)
    if backup_dir.exists():
        shutil.rmtree(backup_dir)


def read_mirror_state(worker_batches_dir: Path) -> dict[str, Any] | None:
    payload = load_json(worker_batches_dir / MIRROR_STATE_NAME, default=None)
    if payload is None:
        return None
    if not isinstance(payload, dict):
        raise ValueError(f"{worker_batches_dir / MIRROR_STATE_NAME}: expected JSON object")
    return payload


def claim_tranche(
    queue_dir: Path,
    tranche_id: int,
    owner: str,
    *,
    worker_batches_dir: Path,
    lease_hours: int = DEFAULT_LEASE_HOURS,
    takeover_expired: bool = False,
) -> dict[str, Any]:
    tranche_dir = tranche_dir_for(queue_dir, tranche_id)
    if not tranche_dir.exists():
        raise ValueError(f"Tranche {tranche_id} does not exist: {tranche_dir}")

    claim = read_claim(tranche_dir)
    if claim.get("status") == "completed":
        raise ValueError(f"Tranche {tranche_id} is already completed.")

    now = utc_now()
    expired = claim_is_expired(claim, now=now)
    current_owner = claim.get("owner")
    if claim.get("status") == "claimed" and current_owner and current_owner != owner and not expired:
        raise ValueError(
            f"Tranche {tranche_id} is currently claimed by {current_owner} until {claim.get('expires_at')}."
        )
    if claim.get("status") == "claimed" and current_owner and current_owner != owner and expired and not takeover_expired:
        raise ValueError(
            f"Tranche {tranche_id} claim by {current_owner} expired at {claim.get('expires_at')}; rerun with --takeover-expired."
        )

    next_claim = {
        "tranche_id": tranche_id,
        "status": "claimed",
        "owner": owner,
        "claimed_at": now.isoformat(),
        "expires_at": (now + timedelta(hours=lease_hours)).isoformat(),
    }
    if claim.get("status") == "claimed" and current_owner and current_owner != owner:
        next_claim["taken_over_from"] = {
            "owner": current_owner,
            "claimed_at": claim.get("claimed_at"),
            "expires_at": claim.get("expires_at"),
        }

    claim_path = tranche_dir / CLAIM_FILE_NAME
    atomic_write_json(claim_path, next_claim)
    update_tranche_status(queue_dir, tranche_id, "claimed", claim_path=claim_path)
    refresh_worker_mirror(tranche_dir, worker_batches_dir, next_claim)
    return next_claim


def release_tranche(queue_dir: Path, tranche_id: int, owner: str) -> dict[str, Any]:
    tranche_dir = tranche_dir_for(queue_dir, tranche_id)
    claim = read_claim(tranche_dir)
    if claim.get("status") == "completed":
        raise ValueError(f"Tranche {tranche_id} is already completed.")
    if claim.get("owner") not in {None, owner}:
        raise ValueError(f"Tranche {tranche_id} is claimed by {claim.get('owner')}, not {owner}.")

    released = {
        "tranche_id": tranche_id,
        "status": "released",
        "owner": None,
        "claimed_at": None,
        "expires_at": None,
    }
    atomic_write_json(tranche_dir / CLAIM_FILE_NAME, released)
    update_tranche_status(queue_dir, tranche_id, "released", claim_path=tranche_dir / CLAIM_FILE_NAME)
    return released


def complete_tranche(queue_dir: Path, tranche_id: int, owner: str) -> dict[str, Any]:
    tranche_dir = tranche_dir_for(queue_dir, tranche_id)
    claim = read_claim(tranche_dir)
    if claim.get("owner") not in {owner, None} and claim.get("status") == "claimed":
        raise ValueError(f"Tranche {tranche_id} is claimed by {claim.get('owner')}, not {owner}.")

    completed = {
        "tranche_id": tranche_id,
        "status": "completed",
        "owner": owner,
        "claimed_at": claim.get("claimed_at"),
        "expires_at": None,
        "completed_at": utc_now().isoformat(),
    }
    atomic_write_json(tranche_dir / CLAIM_FILE_NAME, completed)
    update_tranche_status(queue_dir, tranche_id, "completed", claim_path=tranche_dir / CLAIM_FILE_NAME)
    return completed


def acquire_prepare_lock(queue_dir: Path, *, stale_after_hours: int = DEFAULT_LEASE_HOURS) -> Path:
    queue_dir.mkdir(parents=True, exist_ok=True)
    lock_path = queue_dir / PREPARE_LOCK_NAME
    now = utc_now()
    stale_cutoff = now - timedelta(hours=stale_after_hours)

    while True:
        try:
            fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            payload = load_json(lock_path, default={})
            created_at = parse_timestamp(payload.get("created_at") if isinstance(payload, dict) else None)
            if created_at is not None and created_at <= stale_cutoff:
                lock_path.unlink(missing_ok=True)
                continue
            raise ValueError(f"prepare lock already exists at {lock_path}")
        else:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump({"created_at": now.isoformat(), "pid": os.getpid()}, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
            return lock_path


def release_prepare_lock(lock_path: Path | None) -> None:
    if lock_path is not None:
        lock_path.unlink(missing_ok=True)


def normalize_update_payload(raw_payload: Any, update_path: Path) -> tuple[int | None, int | None, list[dict[str, Any]], bool]:
    if isinstance(raw_payload, list):
        return None, None, raw_payload, True
    if not isinstance(raw_payload, dict):
        raise ValueError(f"{update_path}: expected JSON array or object envelope")
    updates = raw_payload.get("updates")
    if not isinstance(updates, list):
        raise ValueError(f"{update_path}: envelope requires an 'updates' array")
    tranche_id = raw_payload.get("tranche_id")
    batch_id = raw_payload.get("batch_id")
    if not isinstance(tranche_id, int):
        raise ValueError(f"{update_path}: envelope requires integer tranche_id")
    if not isinstance(batch_id, int):
        raise ValueError(f"{update_path}: envelope requires integer batch_id")
    return tranche_id, batch_id, updates, False


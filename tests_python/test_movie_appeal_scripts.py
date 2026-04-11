from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from movie_appeal_reviews import detect_challenge_html, detect_interactive_console  # noqa: E402


class MovieAppealScriptTests(unittest.TestCase):
    def run_script(self, name: str, *args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["uv", "run", "python", str(SCRIPTS / name), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            env=os.environ | (env or {}),
        )

    def test_export_movie_appeal_worker_batches_generates_manifest(self) -> None:
        seed = {
            "ordered_slugs": [f"movie-{idx}" for idx in range(1, 21)],
            "lanes": [],
            "eligibility_mode": "strict",
        }
        catalog = [
            {
                "slug": f"movie-{idx}",
                "title": f"Movie {idx}",
                "displayName": f"Movie {idx}",
                "genres": ["Drama"] if idx % 2 else ["Comedy"],
                "overview": f"overview {idx}",
                "aggregateRating": 4.7,
                "ratingCount": idx * 10,
                "year": 2000 + idx,
            }
            for idx in range(1, 21)
        ]
        source = {
            "movie-2": {
                "summary": "existing summary with \"quote\".",
                "source_quotes": [{"text": "existing sample", "source": "Letterboxd review by Test", "url": "https://example.com"}],
            },
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            seed_path = tmpdir_path / "seed.json"
            catalog_path = tmpdir_path / "catalog.json"
            source_path = tmpdir_path / "source.json"
            output_dir = tmpdir_path / "batches"
            seed_path.write_text(json.dumps(seed), encoding="utf-8")
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            source_path.write_text(json.dumps(source), encoding="utf-8")

            result = self.run_script(
                "export_movie_appeal_worker_batches.py",
                "--seed",
                str(seed_path),
                "--catalog",
                str(catalog_path),
                "--source",
                str(source_path),
                "--output-dir",
                str(output_dir),
                "--batch-size",
                "10",
                "--tranche-id",
                "7",
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            manifest_path = output_dir / "manifest.json"
            self.assertTrue(manifest_path.exists())
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            tranche_index = json.loads((output_dir / "tranche-index.json").read_text(encoding="utf-8"))
            tranche_manifest = json.loads((output_dir / "tranche-manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["count"], 20)
            self.assertEqual(len(manifest["batches"]), 2)
            self.assertEqual(manifest["tranche_id"], 7)
            self.assertEqual(tranche_index["tranche_id"], 7)
            self.assertEqual(tranche_index["update_filename_template"], "movie-appeal-updates-tranche-007-batch-{batch_id:02d}.json")
            self.assertEqual(tranche_manifest["tranche_id"], 7)
            self.assertEqual(tranche_manifest["update_filename_template"], "movie-appeal-updates-tranche-007-batch-{batch_id:02d}.json")

            batch_1 = json.loads((output_dir / "batch-01.json").read_text(encoding="utf-8"))
            self.assertEqual(len(batch_1["slugs"]), 10)
            self.assertEqual(batch_1["tranche_id"], 7)
            self.assertEqual(batch_1["titles"][1]["slug"], "movie-2")
            self.assertTrue(batch_1["titles"][1]["has_existing_entry"])
            self.assertEqual(batch_1["titles"][1]["source_quote_count"], 1)

    def test_merge_movie_appeal_worker_updates_applies_and_dry_runs(self) -> None:
        source = {
            "movie-a": {
                "summary": "People like this because they say \"quiet\" and \"cool\".",
                "appeal_tags": ["quiet energy", "warm atmosphere"],
                "source_quotes": [
                    {"text": "good review", "source": "Letterboxd review by A", "url": "https://letterboxd.com/a/"}
                ],
            }
        }

        update_batch_1 = [
            {
                "slug": "movie-a",
                "summary": "People say this is \"warm and funny,\" which is exactly why it lands.",
                "good_pick_if": "you want an easy watch",
                "source_quotes": [
                    {
                        "text": "warm and funny",
                        "source": "Letterboxd review by B",
                        "url": "https://letterboxd.com/b/",
                    }
                ],
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "movie-appeal-source.json"
            source_path.write_text(json.dumps(source), encoding="utf-8")
            updates_one = tmpdir_path / "updates-01.json"
            updates_one.write_text(json.dumps(update_batch_1), encoding="utf-8")

            dry_run_result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--dry-run",
                str(updates_one),
            )
            self.assertEqual(dry_run_result.returncode, 0, dry_run_result.stderr)
            unchanged_source = json.loads(source_path.read_text(encoding="utf-8"))
            self.assertEqual(unchanged_source, source)

            merge_result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--backup",
                str(updates_one),
            )
            self.assertEqual(merge_result.returncode, 0, merge_result.stderr)
            merged = json.loads(source_path.read_text(encoding="utf-8"))
            self.assertEqual(
                merged["movie-a"]["good_pick_if"],
                "you want an easy watch",
            )
            self.assertEqual(len(merged["movie-a"]["source_quotes"]), 1)
            self.assertEqual(
                merged["movie-a"]["summary"],
                "People say this is \"warm and funny,\" which is exactly why it lands.",
            )
            backup_path = source_path.with_suffix(".json.bak")
            self.assertTrue(backup_path.exists())
            self.assertEqual(json.loads(backup_path.read_text(encoding="utf-8")), source)

    def test_merge_movie_appeal_worker_updates_can_add_new_slugs_when_enabled(self) -> None:
        source = {
            "movie-a": {
                "summary": 'People call it "warm".',
                "source_quotes": [
                    {"text": "warm", "source": "Letterboxd review by A", "url": "https://letterboxd.com/a/"}
                ],
            }
        }
        update_batch = [
            {
                "slug": "movie-b",
                "summary": 'People call it "sharp and funny," and that is the whole pitch.',
                "appeal_tags": ["sharp comedy", "easy momentum"],
                "good_pick_if": "you want something light and quick",
                "confidence": "medium",
                "source_quotes": [
                    {
                        "text": "sharp and funny",
                        "source": "Letterboxd review by B",
                        "url": "https://letterboxd.com/b/",
                    }
                ],
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "movie-appeal-source.json"
            source_path.write_text(json.dumps(source), encoding="utf-8")
            updates_path = tmpdir_path / "updates-01.json"
            updates_path.write_text(json.dumps(update_batch), encoding="utf-8")

            disallowed_result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                str(updates_path),
            )
            self.assertNotEqual(disallowed_result.returncode, 0)
            self.assertIn("slug is not in current source dataset", disallowed_result.stdout)

            allowed_result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--allow-new-slugs",
                str(updates_path),
            )
            self.assertEqual(allowed_result.returncode, 0, allowed_result.stdout + allowed_result.stderr)
            merged = json.loads(source_path.read_text(encoding="utf-8"))

        self.assertIn("movie-b", merged)
        self.assertEqual(merged["movie-b"]["confidence"], "medium")
        self.assertEqual(merged["movie-b"]["appeal_tags"], ["sharp comedy", "easy momentum"])

    def test_claim_movie_appeal_tranche_claim_release_and_takeover(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            queue_dir = tmpdir_path / "queue"
            worker_dir = tmpdir_path / "worker"
            self.make_queued_tranche(queue_dir, tranche_id=3, slugs=["movie-a", "movie-b"])

            claim_result = self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "3",
                "--owner",
                "worker-a",
                "--lease-hours",
                "4",
            )
            self.assertEqual(claim_result.returncode, 0, claim_result.stdout + claim_result.stderr)
            claim_payload = json.loads((queue_dir / "tranche-003" / "claim.json").read_text(encoding="utf-8"))
            self.assertEqual(claim_payload["status"], "claimed")
            self.assertEqual(claim_payload["owner"], "worker-a")
            self.assertTrue((worker_dir / "batch-01.json").exists())
            self.assertEqual(
                json.loads((worker_dir / "tranche-index.json").read_text(encoding="utf-8"))["tranche_id"],
                3,
            )

            blocked_result = self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "3",
                "--owner",
                "worker-b",
            )
            self.assertNotEqual(blocked_result.returncode, 0)
            self.assertIn("claimed by worker-a", blocked_result.stdout)

            stale_claim = claim_payload | {
                "claimed_at": (datetime.now(UTC) - timedelta(hours=6)).isoformat(),
                "expires_at": (datetime.now(UTC) - timedelta(hours=2)).isoformat(),
            }
            (queue_dir / "tranche-003" / "claim.json").write_text(
                json.dumps(stale_claim, indent=2) + "\n",
                encoding="utf-8",
            )

            takeover_result = self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "3",
                "--owner",
                "worker-b",
                "--takeover-expired",
            )
            self.assertEqual(takeover_result.returncode, 0, takeover_result.stdout + takeover_result.stderr)
            claimed_again = json.loads((queue_dir / "tranche-003" / "claim.json").read_text(encoding="utf-8"))
            self.assertEqual(claimed_again["owner"], "worker-b")
            self.assertEqual(claimed_again["taken_over_from"]["owner"], "worker-a")

            release_result = self.run_script(
                "claim_movie_appeal_tranche.py",
                "release",
                "--queue-dir",
                str(queue_dir),
                "--tranche-id",
                "3",
                "--owner",
                "worker-b",
            )
            self.assertEqual(release_result.returncode, 0, release_result.stdout + release_result.stderr)
            released = json.loads((queue_dir / "tranche-003" / "claim.json").read_text(encoding="utf-8"))
            self.assertEqual(released["status"], "released")
            self.assertIsNone(released["owner"])

    def test_claim_movie_appeal_tranche_complete_marks_completed(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            queue_dir = tmpdir_path / "queue"
            worker_dir = tmpdir_path / "worker"
            self.make_queued_tranche(queue_dir, tranche_id=1, slugs=["movie-a"])

            self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "1",
                "--owner",
                "worker-a",
            )
            complete_result = self.run_script(
                "claim_movie_appeal_tranche.py",
                "complete",
                "--queue-dir",
                str(queue_dir),
                "--tranche-id",
                "1",
                "--owner",
                "worker-a",
            )
            self.assertEqual(complete_result.returncode, 0, complete_result.stdout + complete_result.stderr)
            completed = json.loads((queue_dir / "tranche-001" / "claim.json").read_text(encoding="utf-8"))
            self.assertEqual(completed["status"], "completed")

    def test_run_movie_appeal_batches_fails_with_fresh_prepare_lock(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            catalog_path = tmpdir_path / "catalog.json"
            seed_path = tmpdir_path / "seed.json"
            output_dir = tmpdir_path / "batches"
            queue_dir = tmpdir_path / "queue"
            lock_path = queue_dir / ".prepare.lock"
            queue_dir.mkdir(parents=True, exist_ok=True)
            source_path.write_text("{}", encoding="utf-8")
            catalog_path.write_text(json.dumps([self.movie("comedy-next", ["Comedy"], 4.9, 800)]), encoding="utf-8")
            lock_path.write_text(
                json.dumps({"created_at": datetime.now(UTC).isoformat(), "pid": os.getpid()}),
                encoding="utf-8",
            )

            result = self.run_script(
                "run_movie_appeal_batches.py",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--batch-output-dir",
                str(output_dir),
                "--queue-dir",
                str(queue_dir),
                "--per-lane",
                "1",
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("prepare lock", result.stdout)

    def test_run_movie_appeal_batches_replaces_stale_prepare_lock(self) -> None:
        catalog = [
            self.movie("comedy-next", ["Comedy"], 5.0, 900),
            self.movie("drama-next", ["Drama"], 4.9, 800),
            self.movie("thriller-next", ["Thriller"], 4.8, 700),
            self.movie("action-next", ["Action"], 4.7, 600),
            self.movie("family-next", ["Family"], 4.6, 500),
        ]
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            catalog_path = tmpdir_path / "catalog.json"
            seed_path = tmpdir_path / "seed.json"
            output_dir = tmpdir_path / "batches"
            queue_dir = tmpdir_path / "queue"
            lock_path = queue_dir / ".prepare.lock"
            queue_dir.mkdir(parents=True, exist_ok=True)
            source_path.write_text("{}", encoding="utf-8")
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            lock_path.write_text(
                json.dumps({"created_at": (datetime.now(UTC) - timedelta(hours=8)).isoformat(), "pid": os.getpid()}),
                encoding="utf-8",
            )

            result = self.run_script(
                "run_movie_appeal_batches.py",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--batch-output-dir",
                str(output_dir),
                "--queue-dir",
                str(queue_dir),
                "--per-lane",
                "1",
                "--batch-size",
                "2",
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(lock_path.exists())
            queue_manifest = json.loads((queue_dir / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(queue_manifest["count"], 1)

    def test_merge_movie_appeal_worker_updates_rejects_tranche_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            queue_dir = tmpdir_path / "queue"
            worker_dir = tmpdir_path / "worker"
            source_path.write_text("{}", encoding="utf-8")
            self.make_queued_tranche(queue_dir, tranche_id=2, slugs=["movie-a"])
            self.make_queued_tranche(queue_dir, tranche_id=3, slugs=["movie-b"])
            self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "3",
                "--owner",
                "worker-a",
            )

            updates_path = tmpdir_path / "updates.json"
            updates_path.write_text(
                json.dumps(
                    {
                        "tranche_id": 2,
                        "batch_id": 1,
                        "updates": [
                            {
                                "slug": "movie-a",
                                "summary": 'People call it "warm".',
                                "source_quotes": [
                                    {
                                        "text": "warm",
                                        "source": "Letterboxd review by A",
                                        "url": "https://letterboxd.com/a/",
                                    }
                                ],
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--allow-new-slugs",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--owner",
                "worker-a",
                str(updates_path),
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("active mirrored tranche", result.stdout)

    def test_merge_movie_appeal_worker_updates_rejects_completed_tranche(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            queue_dir = tmpdir_path / "queue"
            worker_dir = tmpdir_path / "worker"
            source_path.write_text("{}", encoding="utf-8")
            self.make_queued_tranche(queue_dir, tranche_id=4, slugs=["movie-a"])
            self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "4",
                "--owner",
                "worker-a",
            )
            self.run_script(
                "claim_movie_appeal_tranche.py",
                "complete",
                "--queue-dir",
                str(queue_dir),
                "--tranche-id",
                "4",
                "--owner",
                "worker-a",
            )
            updates_path = tmpdir_path / "updates.json"
            updates_path.write_text(
                json.dumps(
                    {
                        "tranche_id": 4,
                        "batch_id": 1,
                        "updates": [
                            {
                                "slug": "movie-a",
                                "summary": 'People call it "warm".',
                                "source_quotes": [
                                    {
                                        "text": "warm",
                                        "source": "Letterboxd review by A",
                                        "url": "https://letterboxd.com/a/",
                                    }
                                ],
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--allow-new-slugs",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--owner",
                "worker-a",
                str(updates_path),
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already completed", result.stdout)

    def test_merge_movie_appeal_worker_updates_accepts_envelope_when_claim_owner_matches(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            queue_dir = tmpdir_path / "queue"
            worker_dir = tmpdir_path / "worker"
            source_path.write_text("{}", encoding="utf-8")
            self.make_queued_tranche(queue_dir, tranche_id=5, slugs=["movie-a"])
            self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--tranche-id",
                "5",
                "--owner",
                "worker-a",
            )
            updates_path = tmpdir_path / "updates.json"
            updates_path.write_text(
                json.dumps(
                    {
                        "tranche_id": 5,
                        "batch_id": 1,
                        "updates": [
                            {
                                "slug": "movie-a",
                                "summary": 'People call it "warm".',
                                "source_quotes": [
                                    {
                                        "text": "warm",
                                        "source": "Letterboxd review by A",
                                        "url": "https://letterboxd.com/a/",
                                    }
                                ],
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            result = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--allow-new-slugs",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(worker_dir),
                "--owner",
                "worker-a",
                str(updates_path),
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            merged = json.loads(source_path.read_text(encoding="utf-8"))

        self.assertIn("movie-a", merged)

    def test_run_movie_appeal_batches_and_claim_flow_keeps_tranche_ids_distinct(self) -> None:
        catalog = [
            self.movie("comedy-1", ["Comedy"], 5.0, 900),
            self.movie("drama-1", ["Drama"], 4.9, 800),
            self.movie("thriller-1", ["Thriller"], 4.8, 700),
            self.movie("action-1", ["Action"], 4.7, 600),
            self.movie("family-1", ["Family"], 4.6, 500),
            self.movie("comedy-2", ["Comedy"], 4.5, 490),
            self.movie("drama-2", ["Drama"], 4.4, 480),
            self.movie("thriller-2", ["Thriller"], 4.3, 470),
            self.movie("action-2", ["Action"], 4.2, 460),
            self.movie("family-2", ["Family"], 4.1, 450),
        ]
        update_envelope = {
            "tranche_id": 1,
            "batch_id": 1,
            "updates": [
                {
                    "slug": "comedy-1",
                    "summary": 'People call it "warm".',
                    "source_quotes": [
                        {
                            "text": "warm",
                            "source": "Letterboxd review by A",
                            "url": "https://letterboxd.com/a/",
                        }
                    ],
                }
            ],
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            catalog_path = tmpdir_path / "catalog.json"
            seed_path = tmpdir_path / "seed.json"
            runtime_path = tmpdir_path / "runtime.json"
            batch_output_dir = tmpdir_path / "worker"
            queue_dir = tmpdir_path / "queue"
            source_path.write_text("{}", encoding="utf-8")
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")

            first_run = self.run_script(
                "run_movie_appeal_batches.py",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--runtime-output",
                str(runtime_path),
                "--batch-output-dir",
                str(batch_output_dir),
                "--queue-dir",
                str(queue_dir),
                "--per-lane",
                "1",
                "--batch-size",
                "2",
            )
            self.assertEqual(first_run.returncode, 0, first_run.stdout + first_run.stderr)

            claim_run = self.run_script(
                "claim_movie_appeal_tranche.py",
                "claim",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(batch_output_dir),
                "--tranche-id",
                "1",
                "--owner",
                "worker-a",
            )
            self.assertEqual(claim_run.returncode, 0, claim_run.stdout + claim_run.stderr)

            updates_path = tmpdir_path / "updates-01.json"
            updates_path.write_text(json.dumps(update_envelope), encoding="utf-8")
            merge_run = self.run_script(
                "merge_movie_appeal_worker_updates.py",
                "--source",
                str(source_path),
                "--allow-new-slugs",
                "--queue-dir",
                str(queue_dir),
                "--worker-batches-dir",
                str(batch_output_dir),
                "--owner",
                "worker-a",
                str(updates_path),
            )
            self.assertEqual(merge_run.returncode, 0, merge_run.stdout + merge_run.stderr)

            complete_run = self.run_script(
                "claim_movie_appeal_tranche.py",
                "complete",
                "--queue-dir",
                str(queue_dir),
                "--tranche-id",
                "1",
                "--owner",
                "worker-a",
            )
            self.assertEqual(complete_run.returncode, 0, complete_run.stdout + complete_run.stderr)

            second_run = self.run_script(
                "run_movie_appeal_batches.py",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--runtime-output",
                str(runtime_path),
                "--batch-output-dir",
                str(batch_output_dir),
                "--queue-dir",
                str(queue_dir),
                "--per-lane",
                "1",
                "--batch-size",
                "2",
            )
            self.assertEqual(second_run.returncode, 0, second_run.stdout + second_run.stderr)
            queue_manifest = json.loads((queue_dir / "manifest.json").read_text(encoding="utf-8"))
            claim_one = json.loads((queue_dir / "tranche-001" / "claim.json").read_text(encoding="utf-8"))
            claim_two = json.loads((queue_dir / "tranche-002" / "claim.json").read_text(encoding="utf-8"))

        self.assertEqual(queue_manifest["count"], 2)
        self.assertEqual(claim_one["status"], "completed")
        self.assertEqual(claim_two["status"], "unclaimed")

    def test_select_movie_appeal_seed_titles_writes_deterministic_unique_order(self) -> None:
        catalog = [
            self.movie("hybrid", ["Comedy", "Drama", "Romance"], 4.9, 800),
            self.movie("comedy-runner", ["Comedy"], 4.7, 500),
            self.movie("drama-runner", ["Drama"], 4.8, 600),
            self.movie("thriller-pick", ["Thriller"], 4.6, 400),
            self.movie("action-pick", ["Action"], 4.5, 300),
            self.movie("family-pick", ["Family"], 4.4, 200),
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            output_path = tmpdir_path / "seed.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")

            result = self.run_script(
                "select_movie_appeal_seed_titles.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(output_path),
                "--per-lane",
                "1",
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["ordered_slugs"], [
            "hybrid",
            "drama-runner",
            "thriller-pick",
            "action-pick",
            "family-pick",
        ])
        self.assertEqual(payload["lanes"][0]["name"], "comedy")
        self.assertEqual(payload["lanes"][0]["slugs"], ["hybrid"])
        self.assertEqual(payload["lanes"][1]["slugs"], ["drama-runner"])

    def test_select_movie_appeal_seed_titles_can_exclude_existing_source_entries(self) -> None:
        catalog = [
            self.movie("comedy-existing", ["Comedy"], 5.0, 900),
            self.movie("comedy-next", ["Comedy"], 4.9, 800),
            self.movie("drama-existing", ["Drama"], 5.0, 900),
            self.movie("drama-next", ["Drama"], 4.9, 800),
            self.movie("thriller-existing", ["Thriller"], 5.0, 900),
            self.movie("thriller-next", ["Thriller"], 4.9, 800),
            self.movie("action-existing", ["Action"], 5.0, 900),
            self.movie("action-next", ["Action"], 4.9, 800),
            self.movie("family-existing", ["Family"], 5.0, 900),
            self.movie("family-next", ["Family"], 4.9, 800),
        ]
        source = {
            "comedy-existing": {"summary": 'People call it "fun".', "source_quotes": [{"text": "fun", "source": "Letterboxd review by A", "url": "https://example.com/a"}]},
            "drama-existing": {"summary": 'People call it "great".', "source_quotes": [{"text": "great", "source": "Letterboxd review by B", "url": "https://example.com/b"}]},
            "thriller-existing": {"summary": 'People call it "tense".', "source_quotes": [{"text": "tense", "source": "Letterboxd review by C", "url": "https://example.com/c"}]},
            "action-existing": {"summary": 'People call it "huge".', "source_quotes": [{"text": "huge", "source": "Letterboxd review by D", "url": "https://example.com/d"}]},
            "family-existing": {"summary": 'People call it "sweet".', "source_quotes": [{"text": "sweet", "source": "Letterboxd review by E", "url": "https://example.com/e"}]},
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            source_path = tmpdir_path / "source.json"
            output_path = tmpdir_path / "seed.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            source_path.write_text(json.dumps(source), encoding="utf-8")

            result = self.run_script(
                "select_movie_appeal_seed_titles.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(output_path),
                "--per-lane",
                "1",
                "--source",
                str(source_path),
                "--exclude-existing-source",
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["ordered_slugs"], [
            "comedy-next",
            "drama-next",
            "thriller-next",
            "action-next",
            "family-next",
        ])

    def test_select_movie_appeal_seed_titles_returns_empty_payload_when_dataset_is_complete(self) -> None:
        catalog = [
            self.movie("comedy-existing", ["Comedy"], 5.0, 900),
            self.movie("drama-existing", ["Drama"], 5.0, 900),
            self.movie("thriller-existing", ["Thriller"], 5.0, 900),
            self.movie("action-existing", ["Action"], 5.0, 900),
            self.movie("family-existing", ["Family"], 5.0, 900),
        ]
        source = {
            "comedy-existing": {"summary": 'People call it "fun".', "source_quotes": [{"text": "fun", "source": "Letterboxd review by A", "url": "https://example.com/a"}]},
            "drama-existing": {"summary": 'People call it "great".', "source_quotes": [{"text": "great", "source": "Letterboxd review by B", "url": "https://example.com/b"}]},
            "thriller-existing": {"summary": 'People call it "tense".', "source_quotes": [{"text": "tense", "source": "Letterboxd review by C", "url": "https://example.com/c"}]},
            "action-existing": {"summary": 'People call it "huge".', "source_quotes": [{"text": "huge", "source": "Letterboxd review by D", "url": "https://example.com/d"}]},
            "family-existing": {"summary": 'People call it "sweet".', "source_quotes": [{"text": "sweet", "source": "Letterboxd review by E", "url": "https://example.com/e"}]},
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            source_path = tmpdir_path / "source.json"
            output_path = tmpdir_path / "seed.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            source_path.write_text(json.dumps(source), encoding="utf-8")

            result = self.run_script(
                "select_movie_appeal_seed_titles.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(output_path),
                "--per-lane",
                "1",
                "--source",
                str(source_path),
                "--exclude-existing-source",
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["ordered_slugs"], [])
        self.assertEqual(payload["lanes"], [])
        self.assertEqual(payload["eligibility_mode"], "complete")
        self.assertIn("no eligible movie appeal titles remain", result.stdout.lower())

    def test_run_movie_appeal_batches_dry_run_prints_pipeline_steps(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            catalog_path = tmpdir_path / "catalog.json"
            seed_path = tmpdir_path / "seed.json"
            output_dir = tmpdir_path / "batches"
            update_path = tmpdir_path / "updates-01.json"
            source_path.write_text("{}", encoding="utf-8")
            catalog_path.write_text("[]", encoding="utf-8")
            update_path.write_text("[]", encoding="utf-8")

            result = self.run_script(
                "run_movie_appeal_batches.py",
                "--dry-run",
                "--backup",
                "--pretty",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--batch-output-dir",
                str(output_dir),
                str(update_path),
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("merge_movie_appeal_worker_updates.py", result.stdout)
        self.assertIn("--allow-new-slugs", result.stdout)
        self.assertIn("build_movie_appeal.py", result.stdout)
        self.assertIn("select_movie_appeal_seed_titles.py", result.stdout)
        self.assertIn("--exclude-existing-source", result.stdout)
        self.assertIn("export_movie_appeal_worker_batches.py", result.stdout)
        self.assertIn("queue_tranche", result.stdout)

    def test_run_movie_appeal_batches_executes_merge_build_select_export(self) -> None:
        catalog = [
            self.movie("comedy-next", ["Comedy"], 4.9, 800),
            self.movie("drama-next", ["Drama"], 4.9, 800),
            self.movie("thriller-next", ["Thriller"], 4.9, 800),
            self.movie("action-next", ["Action"], 4.9, 800),
            self.movie("family-next", ["Family"], 4.9, 800),
        ]
        source = {
            "movie-a": {
                "summary": 'People call it "warm".',
                "source_quotes": [
                    {"text": "warm", "source": "Letterboxd review by A", "url": "https://letterboxd.com/a/"}
                ],
            }
        }
        update_batch = [
            {
                "slug": "movie-b",
                "summary": 'People call it "sharp and funny," and that is the whole pitch.',
                "appeal_tags": ["sharp comedy", "easy momentum"],
                "good_pick_if": "you want something light and quick",
                "confidence": "medium",
                "source_quotes": [
                    {
                        "text": "sharp and funny",
                        "source": "Letterboxd review by B",
                        "url": "https://letterboxd.com/b/",
                    }
                ],
            }
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            catalog_path = tmpdir_path / "catalog.json"
            seed_path = tmpdir_path / "seed.json"
            runtime_path = tmpdir_path / "runtime.json"
            output_dir = tmpdir_path / "batches"
            queue_dir = tmpdir_path / "queue"
            update_path = tmpdir_path / "updates-01.json"
            source_path.write_text(json.dumps(source), encoding="utf-8")
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            update_path.write_text(json.dumps(update_batch), encoding="utf-8")

            result = self.run_script(
                "run_movie_appeal_batches.py",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--runtime-output",
                str(runtime_path),
                "--batch-output-dir",
                str(output_dir),
                "--queue-dir",
                str(queue_dir),
                "--per-lane",
                "1",
                "--batch-size",
                "2",
                "--backup",
                "--pretty",
                str(update_path),
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            merged = json.loads(source_path.read_text(encoding="utf-8"))
            runtime_payload = json.loads(runtime_path.read_text(encoding="utf-8"))
            seed_payload = json.loads(seed_path.read_text(encoding="utf-8"))
            manifest = json.loads((output_dir / "manifest.json").read_text(encoding="utf-8"))
            tranche_index = json.loads((output_dir / "tranche-index.json").read_text(encoding="utf-8"))
            queue_manifest = json.loads((queue_dir / "manifest.json").read_text(encoding="utf-8"))
            tranche_dir = Path(queue_manifest["tranches"][0]["path"])

            self.assertTrue((tranche_dir / "seed.json").exists())
            self.assertTrue((tranche_dir / "worker-manifest.json").exists())

        self.assertIn("movie-b", merged)
        self.assertIn("movie-b", runtime_payload)
        self.assertEqual(seed_payload["ordered_slugs"], [
            "comedy-next",
            "drama-next",
            "thriller-next",
            "action-next",
            "family-next",
        ])
        self.assertEqual(manifest["count"], 5)
        self.assertEqual(len(manifest["batches"]), 3)
        self.assertEqual(manifest["tranche_id"], 1)
        self.assertEqual(tranche_index["tranche_id"], 1)
        self.assertEqual(queue_manifest["count"], 1)
        self.assertEqual(queue_manifest["tranches"][0]["count"], 5)

    def test_run_movie_appeal_batches_stops_cleanly_when_dataset_is_complete(self) -> None:
        catalog = [
            self.movie("comedy-existing", ["Comedy"], 5.0, 900),
            self.movie("drama-existing", ["Drama"], 5.0, 900),
            self.movie("thriller-existing", ["Thriller"], 5.0, 900),
            self.movie("action-existing", ["Action"], 5.0, 900),
            self.movie("family-existing", ["Family"], 5.0, 900),
        ]
        source = {
            "comedy-existing": {"summary": 'People call it "fun".', "source_quotes": [{"text": "fun", "source": "Letterboxd review by A", "url": "https://example.com/a"}]},
            "drama-existing": {"summary": 'People call it "great".', "source_quotes": [{"text": "great", "source": "Letterboxd review by B", "url": "https://example.com/b"}]},
            "thriller-existing": {"summary": 'People call it "tense".', "source_quotes": [{"text": "tense", "source": "Letterboxd review by C", "url": "https://example.com/c"}]},
            "action-existing": {"summary": 'People call it "huge".', "source_quotes": [{"text": "huge", "source": "Letterboxd review by D", "url": "https://example.com/d"}]},
            "family-existing": {"summary": 'People call it "sweet".', "source_quotes": [{"text": "sweet", "source": "Letterboxd review by E", "url": "https://example.com/e"}]},
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            catalog_path = tmpdir_path / "catalog.json"
            seed_path = tmpdir_path / "seed.json"
            runtime_path = tmpdir_path / "runtime.json"
            output_dir = tmpdir_path / "batches"
            queue_dir = tmpdir_path / "queue"
            source_path.write_text(json.dumps(source), encoding="utf-8")
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")

            result = self.run_script(
                "run_movie_appeal_batches.py",
                "--source",
                str(source_path),
                "--catalog",
                str(catalog_path),
                "--seed-output",
                str(seed_path),
                "--runtime-output",
                str(runtime_path),
                "--batch-output-dir",
                str(output_dir),
                "--queue-dir",
                str(queue_dir),
                "--per-lane",
                "1",
                "--batch-size",
                "2",
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            payload = json.loads(seed_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["ordered_slugs"], [])
        self.assertFalse(output_dir.exists())
        self.assertFalse((queue_dir / "manifest.json").exists())
        self.assertIn("dataset is complete", result.stdout.lower())

    def test_scrape_letterboxd_reviews_executes_complete_set_of_movie_titles(self) -> None:
        catalog = [
            {
                "slug": "alpha",
                "title": "Alpha",
                "letterboxdURL": "https://letterboxd.com/film/alpha/",
            },
            {
                "slug": "beta",
                "title": "Beta",
                "letterboxdURL": "https://letterboxd.com/film/beta/",
            },
            {
                "slug": "gamma",
                "title": "Gamma",
                "letterboxdURL": "https://letterboxd.com/film/gamma/",
            },
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            output_path = tmpdir_path / "letterboxd-reviews.json"
            manifest_path = tmpdir_path / "manifest.json"
            cache_dir = tmpdir_path / "cache"
            html_dir = tmpdir_path / "html"
            html_dir.mkdir()

            catalog_with_review_urls = []
            for movie in catalog:
                review_html_path = html_dir / f"{movie['slug']}.html"
                review_html_path.write_text(
                    self.review_listing_html(movie["title"], movie["slug"]),
                    encoding="utf-8",
                )
                catalog_with_review_urls.append(
                    movie | {"reviewsURL": review_html_path.as_uri()}
                )

            catalog_path.write_text(json.dumps(catalog_with_review_urls), encoding="utf-8")

            result = self.run_script(
                "scrape_letterboxd_reviews.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(output_path),
                "--manifest",
                str(manifest_path),
                "--cache-dir",
                str(cache_dir),
                "--max-reviews",
                "2",
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["processed_count"], 3)
        self.assertEqual(sorted(payload["movies"]), ["alpha", "beta", "gamma"])
        self.assertEqual(
            [payload["movies"][slug]["title"] for slug in ["alpha", "beta", "gamma"]],
            ["Alpha", "Beta", "Gamma"],
        )
        self.assertEqual(
            [payload["movies"][slug]["status"] for slug in ["alpha", "beta", "gamma"]],
            ["ok", "ok", "ok"],
        )
        self.assertEqual(len(payload["movies"]["alpha"]["reviews"]), 2)
        self.assertEqual(payload["movies"]["alpha"]["like_count"], 10)
        self.assertEqual(payload["movies"]["alpha"]["rating_count"], 2)
        self.assertEqual(payload["movies"]["alpha"]["like_to_rating_ratio"], 5.0)
        self.assertIn("scraped 3 titles", result.stdout.lower())

    def test_detect_challenge_html_matches_cloudflare_interstitial(self) -> None:
        html = """
<!DOCTYPE html>
<html lang="en-US">
  <head><title>Just a moment...</title></head>
  <body>
    <span id="challenge-error-text">Enable JavaScript and cookies to continue</span>
    <script>window._cf_chl_opt = { cvId: '3' };</script>
  </body>
</html>
"""
        self.assertTrue(detect_challenge_html(html))

    def test_detect_interactive_console_honors_overrides(self) -> None:
        self.assertTrue(detect_interactive_console("always"))
        self.assertFalse(detect_interactive_console("never"))

    def test_scrape_letterboxd_reviews_challenge_deferred_when_noninteractive(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            output_path = tmpdir_path / "reviews.json"
            manifest_path = tmpdir_path / "manifest.json"
            cache_dir = tmpdir_path / "cache"
            challenge_path = tmpdir_path / "challenge.html"
            challenge_path.write_text(self.cloudflare_challenge_html(), encoding="utf-8")
            catalog_path.write_text(
                json.dumps(
                    [
                        {
                            "slug": "alpha",
                            "title": "Alpha",
                            "letterboxdURL": "https://letterboxd.com/film/alpha/",
                            "reviewsURL": "https://example.com/alpha/reviews/",
                        }
                    ]
                ),
                encoding="utf-8",
            )
            env = {
                "TMNL_SCRAPE_TEST_FETCH_MAP": json.dumps(
                    {"https://example.com/alpha/reviews/": {"kind": "file", "path": str(challenge_path)}}
                )
            }

            result = self.run_script(
                "scrape_letterboxd_reviews.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(output_path),
                "--manifest",
                str(manifest_path),
                "--cache-dir",
                str(cache_dir),
                "--interactive-mode",
                "never",
                "--max-challenge-retries",
                "1",
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["movies"]["alpha"]["status"], "challenge_deferred")
        self.assertEqual(manifest["movies"]["alpha"]["fetch_status"], "challenge_deferred")
        self.assertEqual(manifest["movies"]["alpha"]["challenge_count"], 1)

    def test_scrape_letterboxd_reviews_uses_browser_assist_when_interactive(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            output_path = tmpdir_path / "reviews.json"
            manifest_path = tmpdir_path / "manifest.json"
            cache_dir = tmpdir_path / "cache"
            challenge_path = tmpdir_path / "challenge.html"
            solved_path = tmpdir_path / "solved.html"
            challenge_path.write_text(self.cloudflare_challenge_html(), encoding="utf-8")
            solved_path.write_text(self.review_listing_html("Alpha", "alpha"), encoding="utf-8")
            catalog_path.write_text(
                json.dumps(
                    [
                        {
                            "slug": "alpha",
                            "title": "Alpha",
                            "letterboxdURL": "https://letterboxd.com/film/alpha/",
                            "reviewsURL": "https://example.com/alpha/reviews/",
                        }
                    ]
                ),
                encoding="utf-8",
            )
            env = {
                "TMNL_SCRAPE_TEST_FETCH_MAP": json.dumps(
                    {"https://example.com/alpha/reviews/": {"kind": "file", "path": str(challenge_path)}}
                ),
                "TMNL_SCRAPE_TEST_BROWSER_FETCH_MAP": json.dumps(
                    {"https://example.com/alpha/reviews/": {"kind": "file", "path": str(solved_path)}}
                ),
                "TMNL_SCRAPE_TEST_AUTO_CONFIRM_ASSIST": "1",
            }

            result = self.run_script(
                "scrape_letterboxd_reviews.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(output_path),
                "--manifest",
                str(manifest_path),
                "--cache-dir",
                str(cache_dir),
                "--interactive-mode",
                "always",
                "--allow-user-assist",
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["movies"]["alpha"]["status"], "ok")
        self.assertEqual(manifest["movies"]["alpha"]["assist_mode_used"], "browser")
        self.assertEqual(manifest["movies"]["alpha"]["fetch_status"], "ok")

    def test_scrape_letterboxd_reviews_parse_only_rebuilds_from_cache(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            catalog_path = tmpdir_path / "catalog.json"
            first_output_path = tmpdir_path / "reviews-first.json"
            second_output_path = tmpdir_path / "reviews-second.json"
            manifest_path = tmpdir_path / "manifest.json"
            cache_dir = tmpdir_path / "cache"
            html_dir = tmpdir_path / "html"
            html_dir.mkdir()
            review_html_path = html_dir / "alpha.html"
            review_html_path.write_text(self.review_listing_html("Alpha", "alpha"), encoding="utf-8")
            catalog_path.write_text(
                json.dumps(
                    [
                        {
                            "slug": "alpha",
                            "title": "Alpha",
                            "letterboxdURL": "https://letterboxd.com/film/alpha/",
                            "reviewsURL": review_html_path.as_uri(),
                        }
                    ]
                ),
                encoding="utf-8",
            )

            first = self.run_script(
                "scrape_letterboxd_reviews.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(first_output_path),
                "--manifest",
                str(manifest_path),
                "--cache-dir",
                str(cache_dir),
            )
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)

            second = self.run_script(
                "scrape_letterboxd_reviews.py",
                "--catalog",
                str(catalog_path),
                "--output",
                str(second_output_path),
                "--manifest",
                str(manifest_path),
                "--cache-dir",
                str(cache_dir),
                "--parse-only",
            )
            self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
            payload = json.loads(second_output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["movies"]["alpha"]["status"], "cached_ok")
        self.assertEqual(payload["movies"]["alpha"]["review_count"], 2)

    def test_generate_movie_appeal_summaries_uses_scraped_reviews(self) -> None:
        scraped_reviews = {
            "movies": {
                "alpha": {
                    "slug": "alpha",
                    "title": "Alpha",
                    "status": "ok",
                    "like_count": 10,
                    "rating_count": 2,
                    "like_to_rating_ratio": 5.0,
                    "reviews": [
                        {
                            "author": "alice",
                            "text": "a dreamy, funny hangout movie with real warmth",
                            "url": "https://letterboxd.com/alice/film/alpha/",
                            "like_count": 6,
                            "rating_value": 5.0,
                        },
                        {
                            "author": "bob",
                            "text": "great chemistry and a lovely sense of momentum",
                            "url": "https://letterboxd.com/bob/film/alpha/",
                            "like_count": 4,
                            "rating_value": 4.5,
                        },
                    ],
                }
            }
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            reviews_path = tmpdir_path / "reviews.json"
            output_path = tmpdir_path / "summary-drafts.json"
            reviews_path.write_text(json.dumps(scraped_reviews), encoding="utf-8")

            result = self.run_script(
                "generate_movie_appeal_summaries.py",
                "--reviews",
                str(reviews_path),
                "--output",
                str(output_path),
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertIn("alpha", payload)
        self.assertIn('"a dreamy, funny hangout movie with real warmth"', payload["alpha"]["summary"])
        self.assertEqual(len(payload["alpha"]["source_quotes"]), 2)
        self.assertEqual(
            payload["alpha"]["source_quotes"][0]["source"],
            "Letterboxd review by alice",
        )

    def test_build_movie_appeal_normalizes_valid_entries(self) -> None:
        source = {
            "alpha": {
                "summary": 'People call this "the easiest movie in the world to settle into," which gets at why it lands for a movie night.',
                "appeal_tags": ["easy chemistry", "comfort-watch energy"],
                "good_pick_if": "you want something light and friendly",
                "confidence": "medium",
                "source_quotes": [
                    {
                        "text": "This felt like the easiest movie in the world to settle into.",
                        "source": "Letterboxd review by Example",
                        "url": "https://letterboxd.com/example/film/alpha/"
                    }
                ]
            }
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            output_path = tmpdir_path / "appeal.json"
            source_path.write_text(json.dumps(source), encoding="utf-8")

            result = self.run_script(
                "build_movie_appeal.py",
                "--source",
                str(source_path),
                "--output",
                str(output_path),
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["alpha"]["appeal_tags"], ["easy chemistry", "comfort-watch energy"])
        self.assertNotIn("maybe_skip_if", payload["alpha"])
        self.assertNotIn("source_quotes", payload["alpha"])

    def test_build_movie_appeal_rejects_invalid_confidence_and_too_many_tags(self) -> None:
        source = {
            "alpha": {
                "summary": "People like this because it lands hard, moves fast, and keeps the room buzzing well past the credits.",
                "appeal_tags": ["wild momentum", "big swings", "crowd-pleaser energy", "extra tag"],
                "confidence": "certain",
            }
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            output_path = tmpdir_path / "appeal.json"
            source_path.write_text(json.dumps(source), encoding="utf-8")

            result = self.run_script(
                "build_movie_appeal.py",
                "--source",
                str(source_path),
                "--output",
                str(output_path),
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("confidence", result.stderr)

    def test_build_movie_appeal_requires_quote_backed_summary(self) -> None:
        source = {
            "alpha": {
                "summary": "People like this because it feels warm, funny, and easy to sink into.",
                "appeal_tags": ["easy chemistry", "comfort-watch energy"],
                "confidence": "medium",
            }
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            source_path = tmpdir_path / "source.json"
            output_path = tmpdir_path / "appeal.json"
            source_path.write_text(json.dumps(source), encoding="utf-8")

            result = self.run_script(
                "build_movie_appeal.py",
                "--source",
                str(source_path),
                "--output",
                str(output_path),
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source_quotes", result.stderr)
        self.assertIn("quoted fragment", result.stderr)

    def test_reviewed_movie_appeal_source_entries_all_have_summaries(self) -> None:
        source_path = ROOT / "Data" / "movie-appeal-source.json"
        payload = json.loads(source_path.read_text(encoding="utf-8"))

        self.assertIsInstance(payload, dict)
        missing = sorted(
            slug
            for slug, entry in payload.items()
            if not isinstance(entry, dict)
            or not isinstance(entry.get("summary"), str)
            or not entry["summary"].strip()
        )
        self.assertEqual(missing, [], f"Entries missing summaries: {missing[:20]}")

    def test_full_catalog_has_movie_appeal_coverage(self) -> None:
        catalog_path = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
        source_path = ROOT / "Data" / "movie-appeal-source.json"
        runtime_path = ROOT / "Sources" / "TMNLCore" / "Resources" / "movie-appeal.json"

        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        source = json.loads(source_path.read_text(encoding="utf-8"))
        runtime = json.loads(runtime_path.read_text(encoding="utf-8"))

        catalog_slugs = sorted(
            movie["slug"]
            for movie in catalog
            if isinstance(movie, dict) and isinstance(movie.get("slug"), str)
        )
        source_slugs = set(source)
        runtime_slugs = set(runtime)

        missing_from_source = [slug for slug in catalog_slugs if slug not in source_slugs]
        missing_from_runtime = [slug for slug in catalog_slugs if slug not in runtime_slugs]

        self.assertEqual(
            missing_from_source,
            [],
            f"Catalog movies missing reviewed source coverage: {missing_from_source[:20]}",
        )
        self.assertEqual(
            missing_from_runtime,
            [],
            f"Catalog movies missing bundled runtime coverage: {missing_from_runtime[:20]}",
        )

    def movie(
        self,
        slug: str,
        genres: list[str],
        rating: float,
        rating_count: int,
    ) -> dict[str, object]:
        return {
            "number": rating_count,
            "slug": slug,
            "title": slug.replace("-", " ").title(),
            "year": 2000,
            "displayName": slug.replace("-", " ").title(),
            "letterboxdURL": f"https://letterboxd.com/film/{slug}/",
            "watchURL": f"https://letterboxd.com/film/{slug}/watch/",
            "posterURL": f"https://example.com/{slug}.jpg",
            "aggregateRating": rating,
            "ratingCount": rating_count,
            "genres": genres,
            "tmdbMovieID": rating_count,
            "runtimeMinutes": 100,
            "certification": None,
            "backdropURL": None,
            "overview": f"{slug} overview",
            "tagline": None,
            "director": None,
            "cast": [],
        }

    def make_queued_tranche(self, queue_dir: Path, *, tranche_id: int, slugs: list[str]) -> None:
        tranche_dir = queue_dir / f"tranche-{tranche_id:03d}"
        tranche_dir.mkdir(parents=True, exist_ok=True)
        tranche_index = {
            "tranche_id": tranche_id,
            "count": len(slugs),
            "batch_size": len(slugs),
            "total_batches": 1,
            "update_filename_template": f"movie-appeal-updates-tranche-{tranche_id:03d}-batch-{{batch_id:02d}}.json",
        }
        worker_manifest = {
            "tranche_id": tranche_id,
            "source_seed": str(tranche_dir / "seed.json"),
            "source_catalog": str(tranche_dir / "catalog.json"),
            "source_dataset": str(tranche_dir / "source.json"),
            "batch_size": len(slugs),
            "count": len(slugs),
            "batches": [
                {
                    "batch_id": 1,
                    "path": str(tranche_dir / "batch-01.json"),
                    "count": len(slugs),
                }
            ],
        }
        tranche_manifest = {
            "tranche_id": tranche_id,
            "count": len(slugs),
            "batch_size": len(slugs),
            "total_batches": 1,
            "update_filename_template": tranche_index["update_filename_template"],
            "batches": [
                {
                    "batch_id": 1,
                    "filename": "batch-01.json",
                    "slugs": slugs,
                }
            ],
        }
        batch_payload = {
            "tranche_id": tranche_id,
            "batch_id": 1,
            "total_batches": 1,
            "batch_size": len(slugs),
            "slug_range": {"start": 0, "end": len(slugs) - 1},
            "slugs": slugs,
            "dispatch_prompt": "Draft concise, spoiler-safe Why People Like It updates for these slugs.",
            "titles": [
                {
                    "slug": slug,
                    "title": slug,
                    "genres": ["Drama"],
                    "has_existing_entry": False,
                    "source_quote_count": 0,
                }
                for slug in slugs
            ],
        }
        claim_payload = {
            "tranche_id": tranche_id,
            "status": "unclaimed",
            "owner": None,
            "claimed_at": None,
            "expires_at": None,
        }
        queue_dir.mkdir(parents=True, exist_ok=True)
        (tranche_dir / "seed.json").write_text(json.dumps({"ordered_slugs": slugs}), encoding="utf-8")
        (tranche_dir / "worker-manifest.json").write_text(json.dumps(worker_manifest, indent=2) + "\n", encoding="utf-8")
        (tranche_dir / "tranche-manifest.json").write_text(json.dumps(tranche_manifest, indent=2) + "\n", encoding="utf-8")
        (tranche_dir / "tranche-index.json").write_text(json.dumps(tranche_index, indent=2) + "\n", encoding="utf-8")
        (tranche_dir / "batch-01.json").write_text(json.dumps(batch_payload, indent=2) + "\n", encoding="utf-8")
        (tranche_dir / "claim.json").write_text(json.dumps(claim_payload, indent=2) + "\n", encoding="utf-8")
        manifest_path = queue_dir / "manifest.json"
        if manifest_path.exists():
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        else:
            manifest = {"count": 0, "tranches": []}

        manifest["tranches"] = [entry for entry in manifest["tranches"] if entry["tranche_id"] != tranche_id]
        manifest["tranches"].append(
            {
                "tranche_id": tranche_id,
                "path": str(tranche_dir),
                "seed_path": str(tranche_dir / "seed.json"),
                "worker_manifest_path": str(tranche_dir / "worker-manifest.json"),
                "tranche_index_path": str(tranche_dir / "tranche-index.json"),
                "claim_path": str(tranche_dir / "claim.json"),
                "count": len(slugs),
                "status": "queued",
            }
        )
        manifest["tranches"] = sorted(manifest["tranches"], key=lambda entry: entry["tranche_id"])
        manifest["count"] = len(manifest["tranches"])
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    def review_listing_html(self, title: str, slug: str) -> str:
        return f"""
<!DOCTYPE html>
<html lang="en">
  <body>
    <section class="reviews">
      <article>
        <h2>{title}</h2>
        <p>★★★★★ Liked Watched 12 Mar 2026 6</p>
        <p>Watched by alice 12 Mar 2026</p>
        <p>a dreamy, funny hangout movie with real warmth</p>
        <a href="https://letterboxd.com/alice/film/{slug}/">Permalink</a>
        <p>Translate</p>
      </article>
      <article>
        <h2>{title}</h2>
        <p>★★★★½ Liked Watched 11 Mar 2026 4</p>
        <p>Watched by bob 11 Mar 2026</p>
        <p>great chemistry and a lovely sense of momentum</p>
        <a href="https://letterboxd.com/bob/film/{slug}/">Permalink</a>
        <p>Translate</p>
      </article>
    </section>
  </body>
</html>
"""

    def cloudflare_challenge_html(self) -> str:
        return """
<!DOCTYPE html>
<html lang="en-US">
  <head><title>Just a moment...</title></head>
  <body>
    <span id="challenge-error-text">Enable JavaScript and cookies to continue</span>
    <script>window._cf_chl_opt = { cvId: '3' };</script>
  </body>
</html>
"""


if __name__ == "__main__":
    unittest.main()

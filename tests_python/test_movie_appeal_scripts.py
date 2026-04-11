from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"


class MovieAppealScriptTests(unittest.TestCase):
    def run_script(self, name: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["uv", "run", "python", str(SCRIPTS / name), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
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
            self.assertEqual(manifest["count"], 20)
            self.assertEqual(len(manifest["batches"]), 2)
            self.assertEqual(manifest["tranche_id"], 7)
            self.assertEqual(tranche_index["tranche_id"], 7)
            self.assertEqual(tranche_index["update_filename_template"], "movie-appeal-updates-tranche-007-batch-{batch_id:02d}.json")

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


if __name__ == "__main__":
    unittest.main()

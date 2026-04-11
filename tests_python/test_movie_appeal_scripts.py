from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"


class MovieAppealScriptTests(unittest.TestCase):
    def run_script(self, name: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPTS / name), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

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

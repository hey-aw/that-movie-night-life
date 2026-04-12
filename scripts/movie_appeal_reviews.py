from __future__ import annotations

import json
import os
import random
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CATALOG_PATH = ROOT / "Sources" / "TMNLCore" / "Resources" / "movies.catalog.json"
DEFAULT_REVIEWS_OUTPUT_PATH = ROOT / "Data" / "letterboxd-reviews.json"
DEFAULT_SUMMARY_OUTPUT_PATH = ROOT / "Data" / "movie-appeal-summary-drafts.json"
DEFAULT_CACHE_DIR = ROOT / "Data" / "letterboxd-review-cache"
DEFAULT_MANIFEST_PATH = ROOT / "Data" / "letterboxd-review-manifest.json"
DEFAULT_PLAYWRIGHT_STATE_PATH = ROOT / "Data" / "letterboxd-playwright-state.json"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0_0) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
)
WATCHED_BY_PATTERN = re.compile(
    r"^Watched by (?P<author>.+?) \d{1,2} [A-Za-z]{3} \d{4}(?: \d+)?$"
)
REVIEW_BY_PATTERN = re.compile(r"^Review by (?P<author>.+?)(?: [★½]+.*)?$")
REVIEW_URL_PATTERN_TEMPLATE = r"https?://letterboxd\.com/[^/]+/film/{slug}/(?:\d+/)?"
RATING_LINE_PATTERN = re.compile(
    r"^(?P<stars>[★½]+)(?:\s+Liked)?(?:\s+Rewatched)?(?:\s+Watched)?(?:\s+\d{1,2} [A-Za-z]{3} \d{4})?(?:\s+(?P<likes>\d+))?$"
)
SKIP_LINE_PREFIXES = (
    "Translate",
    "Translated from",
    "Newer",
    "Older",
    "Review Tags",
    "Visibility Filters",
    "Sort by",
)
CHALLENGE_MARKERS = (
    "Just a moment...",
    "Enable JavaScript and cookies to continue",
    "__cf_chl_opt",
    "/cdn-cgi/challenge-platform/",
)
SUCCESS_FETCH_STATUSES = {"ok", "cached_ok"}
RETRYABLE_FETCH_STATUSES = {"fetch_error", "challenge", "challenge_deferred", "unexpected_html"}
_TEST_FETCH_COUNTERS: dict[tuple[str, str], int] = {}


class HTMLTextExtractor(HTMLParser):
    BLOCK_TAGS = {
        "article",
        "aside",
        "blockquote",
        "br",
        "div",
        "figcaption",
        "footer",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "header",
        "li",
        "main",
        "p",
        "section",
        "span",
        "time",
        "ul",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self._suppress_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style"}:
            self._suppress_depth += 1
            return
        if self._suppress_depth == 0 and tag in self.BLOCK_TAGS:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"} and self._suppress_depth > 0:
            self._suppress_depth -= 1
            return
        if self._suppress_depth == 0 and tag in self.BLOCK_TAGS:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._suppress_depth == 0 and data.strip():
            self.parts.append(data)

    def get_lines(self) -> list[str]:
        text = "".join(self.parts)
        lines = [normalize_whitespace(line) for line in text.splitlines()]
        return [line for line in lines if line]


class ReviewBodyExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self._suppress_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style"}:
            self._suppress_depth += 1
            return
        if self._suppress_depth == 0 and tag in {"p", "br", "div"}:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"} and self._suppress_depth > 0:
            self._suppress_depth -= 1
            return
        if self._suppress_depth == 0 and tag in {"p", "br", "div"}:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._suppress_depth == 0 and data.strip():
            self.parts.append(data)

    def get_text(self) -> str:
        lines = [normalize_whitespace(line) for line in "".join(self.parts).splitlines()]
        return normalize_whitespace(" ".join(line for line in lines if line and line != "more"))


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def now_utc_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def normalize_whitespace(value: str) -> str:
    return " ".join(value.split())


def load_catalog(path: Path) -> list[dict[str, Any]]:
    payload = load_json(path)
    if not isinstance(payload, list):
        raise ValueError(f"Catalog must be a JSON array: {path}")
    catalog: list[dict[str, Any]] = []
    for movie in payload:
        if not isinstance(movie, dict):
            continue
        slug = movie.get("slug")
        title = movie.get("title") or movie.get("displayName")
        letterboxd_url = movie.get("letterboxdURL")
        if not isinstance(slug, str) or not isinstance(title, str) or not isinstance(letterboxd_url, str):
            continue
        catalog.append(movie)
    return catalog


def build_reviews_url(movie: dict[str, Any]) -> str:
    explicit = movie.get("reviewsURL")
    if isinstance(explicit, str) and explicit.strip():
        return explicit.strip()
    letterboxd_url = movie["letterboxdURL"].rstrip("/")
    return f"{letterboxd_url}/reviews/"


def load_test_fetch_map(env_name: str) -> dict[str, dict[str, str]]:
    raw = os.environ.get(env_name)
    if not raw:
        return {}
    payload = json.loads(raw)
    return payload if isinstance(payload, dict) else {}


def _resolve_test_fetch_spec(url: str, env_name: str) -> dict[str, Any] | None:
    fetch_map = load_test_fetch_map(env_name)
    spec = fetch_map.get(url)
    if not isinstance(spec, dict):
        return None
    sequence = spec.get("sequence")
    if isinstance(sequence, list) and sequence:
        key = (env_name, url)
        index = _TEST_FETCH_COUNTERS.get(key, 0)
        _TEST_FETCH_COUNTERS[key] = index + 1
        selected = sequence[min(index, len(sequence) - 1)]
        return selected if isinstance(selected, dict) else None
    return spec


def _resolve_test_fetch(url: str, env_name: str) -> str | None:
    spec = _resolve_test_fetch_spec(url, env_name)
    if not isinstance(spec, dict):
        return None
    kind = spec.get("kind")
    if kind == "file":
        path = spec.get("path")
        if not isinstance(path, str):
            raise ValueError(f"Missing file path for {env_name} test fetch of {url}")
        return Path(path).read_text(encoding="utf-8")
    if kind == "text":
        text = spec.get("text")
        if not isinstance(text, str):
            raise ValueError(f"Missing text for {env_name} test fetch of {url}")
        return text
    if kind == "error":
        message = spec.get("message") or f"test fetch error for {url}"
        raise RuntimeError(str(message))
    if kind == "http_error":
        code = spec.get("code")
        if not isinstance(code, int):
            raise ValueError(f"Missing integer code for {env_name} test fetch of {url}")
        raise urllib.error.HTTPError(url, code, f"HTTP {code}", hdrs=None, fp=None)
    raise ValueError(f"Unsupported {env_name} test fetch kind: {kind!r}")


def fetch_text(url: str, *, timeout: int = 30, test_env_name: str = "TMNL_SCRAPE_TEST_FETCH_MAP") -> str:
    resolved = _resolve_test_fetch(url, test_env_name)
    if resolved is not None:
        return resolved
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


def detect_challenge_html(page_html: str) -> bool:
    lowered = page_html.lower()
    return any(marker.lower() in lowered for marker in CHALLENGE_MARKERS)


def detect_interactive_console(mode: str) -> bool:
    if mode == "always":
        return True
    if mode == "never":
        return False
    return sys.stdin.isatty() and sys.stdout.isatty()


def compute_backoff_seconds(attempt: int, *, base: float, maximum: float) -> float:
    return min(maximum, base * (2 ** max(0, attempt - 1)) + random.uniform(0, base))


def sleep_with_backoff(attempt: int, *, base: float, maximum: float) -> None:
    time.sleep(compute_backoff_seconds(attempt, base=base, maximum=maximum))


def cache_path_for_slug(cache_dir: Path, slug: str) -> Path:
    return cache_dir / f"{slug}.html"


def cache_is_fresh(path: Path, *, max_age_hours: int | None) -> bool:
    if not path.exists():
        return False
    if max_age_hours is None:
        return True
    age_seconds = max(0.0, time.time() - path.stat().st_mtime)
    return age_seconds <= (max_age_hours * 3600)


def read_cache_html(cache_dir: Path, slug: str) -> str:
    return cache_path_for_slug(cache_dir, slug).read_text(encoding="utf-8")


def write_cache_html(cache_dir: Path, slug: str, page_html: str) -> Path:
    path = cache_path_for_slug(cache_dir, slug)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(page_html, encoding="utf-8")
    return path


def load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"generated_at": None, "movies": {}}
    payload = load_json(path)
    if not isinstance(payload, dict):
        return {"generated_at": None, "movies": {}}
    movies = payload.get("movies")
    if not isinstance(movies, dict):
        payload["movies"] = {}
    return payload


def save_manifest(path: Path, manifest: dict[str, Any]) -> None:
    manifest["generated_at"] = now_utc_iso()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def ensure_manifest_entry(manifest: dict[str, Any], *, slug: str, reviews_url: str) -> dict[str, Any]:
    movies = manifest.setdefault("movies", {})
    assert isinstance(movies, dict)
    entry = movies.setdefault(
        slug,
        {
            "reviews_url": reviews_url,
            "fetch_status": None,
            "parser_status": None,
            "attempt_count": 0,
            "http_status": None,
            "fetched_at": None,
            "last_error": None,
            "challenge_count": 0,
            "assist_mode_used": None,
        },
    )
    if isinstance(entry, dict):
        entry["reviews_url"] = reviews_url
    return entry


def is_unexpected_html(page_html: str) -> bool:
    lowered = page_html.lower()
    return "<html" not in lowered and "<!doctype html" not in lowered


def prompt_for_browser_assist(url: str) -> None:
    if os.environ.get("TMNL_SCRAPE_TEST_AUTO_CONFIRM_ASSIST") == "1":
        return
    print(f"Letterboxd challenge detected for {url}. Solve it in the browser, then press Enter to continue.")
    input()


def persist_playwright_storage_state(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        return
    path.write_text(json.dumps({"cookies": [], "origins": []}, indent=2) + "\n", encoding="utf-8")


def browser_app_name() -> str:
    return os.environ.get("TMNL_SCRAPE_BROWSER_APP", "Safari").strip() or "Safari"


def open_url_in_browser(url: str) -> None:
    if sys.platform == "darwin":
        subprocess.run(["open", "-a", browser_app_name(), url], check=False)
        return
    subprocess.run(["open", url], check=False)


def fetch_text_via_browser(url: str) -> str:
    resolved = _resolve_test_fetch(url, "TMNL_SCRAPE_TEST_BROWSER_FETCH_MAP")
    if resolved is not None:
        return resolved
    open_url_in_browser(url)
    if sys.platform != "darwin":
        raise RuntimeError("Browser assist is only implemented on macOS Safari in this script.")
    app_name = browser_app_name()
    if app_name == "Safari":
        script = f'''
tell application "Safari"
    activate
    if (count of windows) = 0 then
        make new document with properties {{URL:"{url}"}}
    else
        set URL of current tab of front window to "{url}"
    end if
end tell
'''
        html_script = '''
tell application "Safari"
    return do JavaScript "document.documentElement.outerHTML" in current tab of front window
end tell
'''
    elif app_name == "Google Chrome":
        script = f'''
tell application "Google Chrome"
    activate
    if (count of windows) = 0 then
        make new window
    end if
    if (count of tabs of front window) = 0 then
        make new tab at end of tabs of front window with properties {{URL:"{url}"}}
    else
        set URL of active tab of front window to "{url}"
    end if
end tell
'''
        html_script = '''
tell application "Google Chrome"
    return execute active tab of front window javascript "document.documentElement.outerHTML"
end tell
'''
    else:
        raise RuntimeError(f"Unsupported browser app for assist: {app_name}")

    subprocess.run(["osascript", "-e", script], check=False)
    prompt_for_browser_assist(url)
    completed = subprocess.run(
        ["osascript", "-e", html_script],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"Unable to capture HTML from {app_name}.")
    return completed.stdout


class PlaywrightBrowserSession:
    def __init__(
        self,
        *,
        storage_state_path: Path,
        headless: bool,
        page_timeout_ms: int,
        settle_time_ms: int,
    ) -> None:
        self.storage_state_path = storage_state_path
        self.headless = headless
        self.page_timeout_ms = page_timeout_ms
        self.settle_time_ms = settle_time_ms
        self._current_url: str | None = None
        self._playwright: Any = None
        self._browser: Any = None
        self._context: Any = None
        self._page: Any = None
        self._timeout_error: type[Exception] | None = None

    def _safe_call(self, callback: Any) -> None:
        try:
            callback()
        except Exception:  # noqa: BLE001
            # Shutdown is best-effort. Interrupts can leave Playwright objects already closed.
            return

    def _ensure_runtime(self) -> None:
        if os.environ.get("TMNL_SCRAPE_TEST_PLAYWRIGHT_FETCH_MAP"):
            persist_playwright_storage_state(self.storage_state_path)
            return
        if self._playwright is not None:
            return
        try:
            from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
            from playwright.sync_api import sync_playwright
        except ImportError as exc:
            raise RuntimeError(
                "Playwright is not available. Install dependencies with `uv sync` and browser binaries with "
                "`uv run playwright install chromium`."
            ) from exc

        self._timeout_error = PlaywrightTimeoutError
        self._playwright = sync_playwright().start()
        self._browser = self._playwright.chromium.launch(headless=self.headless)
        context_kwargs: dict[str, Any] = {}
        if self.storage_state_path.exists():
            context_kwargs["storage_state"] = str(self.storage_state_path)
        self._context = self._browser.new_context(**context_kwargs)
        self._page = self._context.new_page()
        self._page.set_default_timeout(self.page_timeout_ms)

    def _persist_storage_state(self) -> None:
        if self._context is None:
            persist_playwright_storage_state(self.storage_state_path)
            return
        self.storage_state_path.parent.mkdir(parents=True, exist_ok=True)
        self._context.storage_state(path=str(self.storage_state_path))

    def _fetch_test_html(self, url: str) -> str | None:
        resolved = _resolve_test_fetch(url, "TMNL_SCRAPE_TEST_PLAYWRIGHT_FETCH_MAP")
        if resolved is None:
            return None
        self._current_url = url
        self._persist_storage_state()
        return resolved

    def fetch_page_html(self, url: str) -> str:
        test_html = self._fetch_test_html(url)
        if test_html is not None:
            return test_html

        self._ensure_runtime()
        assert self._page is not None
        self._current_url = url
        try:
            self._page.goto(url, wait_until="domcontentloaded", timeout=self.page_timeout_ms)
            self._page.wait_for_timeout(self.settle_time_ms)
        except Exception as exc:  # noqa: BLE001
            if self._timeout_error is not None and isinstance(exc, self._timeout_error):
                raise RuntimeError(f"Timed out loading {url}") from exc
            raise RuntimeError(str(exc)) from exc

        html = self._page.content()
        self._persist_storage_state()
        return html

    def reread_current_page_html(self) -> str:
        if self._current_url is None:
            raise RuntimeError("No current Playwright page is available to reread.")
        test_html = self._fetch_test_html(self._current_url)
        if test_html is not None:
            return test_html

        self._ensure_runtime()
        assert self._page is not None
        self._page.wait_for_timeout(self.settle_time_ms)
        html = self._page.content()
        self._persist_storage_state()
        return html

    def close(self) -> None:
        if self._context is not None:
            self._safe_call(self._persist_storage_state)
        if self._page is not None:
            self._safe_call(self._page.close)
        if self._context is not None:
            self._safe_call(self._context.close)
        if self._browser is not None:
            self._safe_call(self._browser.close)
        if self._playwright is not None:
            self._safe_call(self._playwright.stop)


def html_to_lines(page_html: str) -> list[str]:
    parser = HTMLTextExtractor()
    parser.feed(page_html)
    parser.close()
    return parser.get_lines()


def extract_review_urls(page_html: str, slug: str) -> list[str]:
    pattern = re.compile(REVIEW_URL_PATTERN_TEMPLATE.format(slug=re.escape(slug)))
    urls = []
    seen: set[str] = set()
    for match in pattern.finditer(page_html):
        url = match.group(0)
        if url not in seen:
            seen.add(url)
            urls.append(url)
    return urls


def is_metadata_line(line: str) -> bool:
    if not line:
        return True
    if line.startswith(SKIP_LINE_PREFIXES):
        return True
    if re.fullmatch(r"\d{4}", line):
        return True
    if line.startswith("★") or line.endswith("Liked") or line.endswith("Watched"):
        return True
    return False


def parse_rating_value(stars: str) -> float:
    return float(stars.count("★")) + (0.5 if "½" in stars else 0.0)


def parse_rating_line(line: str) -> tuple[float | None, int | None]:
    match = RATING_LINE_PATTERN.match(line)
    if match is None:
        return None, None
    likes = match.group("likes")
    return parse_rating_value(match.group("stars")), (int(likes) if likes is not None else None)


def aggregate_movie_metrics(reviews: list[dict[str, Any]]) -> dict[str, int | float | None]:
    total_like_count = 0
    rating_count = 0
    for review in reviews:
        like_count = review.get("like_count")
        rating_value = review.get("rating_value")
        if isinstance(like_count, int):
            total_like_count += like_count
        if isinstance(rating_value, (int, float)):
            rating_count += 1
    return {
        "like_count": total_like_count,
        "rating_count": rating_count,
        "like_to_rating_ratio": round(total_like_count / rating_count, 2) if rating_count else None,
    }


def extract_reviews_from_letterboxd_articles(page_html: str, *, slug: str, max_reviews: int) -> list[dict[str, Any]]:
    article_pattern = re.compile(
        r'<article class="production-viewing -viewing".*?</article>\s*</div>',
        re.S,
    )
    rating_pattern = re.compile(r'aria-label="(?P<rating>[★½]+)"')
    author_pattern = re.compile(
        rf'<a href="(?P<url>/[^"]+/film/{re.escape(slug)}(?:/\d+/)?/?)" class="context">\s*(?:Rewatched by|Watched by)\s*<span class="owner"><strong class="displayname">(?P<author>.*?)</strong>',
        re.S,
    )
    like_pattern = re.compile(r'data-count="(?P<count>\d+)"')
    body_pattern = re.compile(
        r'<div class="body-text -prose -reset js-review-body js-collapsible-text".*?>(?P<body>.*?)</div>\s*<div class="viewing-actions">',
        re.S,
    )

    reviews: list[dict[str, Any]] = []
    for article in article_pattern.findall(page_html):
        author_match = author_pattern.search(article)
        body_match = body_pattern.search(article)
        if author_match is None or body_match is None:
            continue

        body_extractor = ReviewBodyExtractor()
        body_extractor.feed(body_match.group("body"))
        body_extractor.close()
        text = body_extractor.get_text()
        if not text:
            continue

        rating_match = rating_pattern.search(article)
        like_match = like_pattern.search(article)
        review_url = author_match.group("url")
        if review_url.startswith("/"):
            review_url = f"https://letterboxd.com{review_url}"
        reviews.append(
            {
                "author": normalize_whitespace(author_match.group("author")),
                "text": text,
                "url": review_url,
                "like_count": int(like_match.group("count")) if like_match else None,
                "rating_value": parse_rating_value(rating_match.group("rating")) if rating_match else None,
            }
        )
        if len(reviews) >= max_reviews:
            break
    return reviews


def extract_reviews_from_html_fallback(page_html: str, *, slug: str, max_reviews: int) -> list[dict[str, Any]]:
    listing_reviews = extract_reviews_from_letterboxd_articles(page_html, slug=slug, max_reviews=max_reviews)
    if listing_reviews:
        return listing_reviews
    review_url_pattern = re.compile(REVIEW_URL_PATTERN_TEMPLATE.format(slug=re.escape(slug)))
    article_pattern = re.compile(r"<article\b.*?</article>", re.S | re.I)
    reviews: list[dict[str, Any]] = []
    for article in article_pattern.findall(page_html):
        parser = HTMLTextExtractor()
        parser.feed(article)
        parser.close()
        lines = parser.get_lines()
        if not lines:
            continue
        review_url_match = review_url_pattern.search(article)
        author: str | None = None
        like_count: int | None = None
        rating_value: float | None = None
        content_lines: list[str] = []
        for line in lines:
            watched_match = WATCHED_BY_PATTERN.match(line)
            if watched_match:
                author = normalize_whitespace(watched_match.group("author"))
                continue
            parsed_rating, parsed_likes = parse_rating_line(line)
            if parsed_rating is not None:
                rating_value = parsed_rating
                like_count = parsed_likes
                continue
            if not is_metadata_line(line) and line != "Permalink":
                content_lines.append(line)
        text = normalize_whitespace(" ".join(content_lines))
        if author and text and review_url_match:
            reviews.append(
                {
                    "author": author,
                    "text": text,
                    "url": review_url_match.group(0),
                    "like_count": like_count,
                    "rating_value": rating_value,
                }
            )
        if len(reviews) >= max_reviews:
            break
    return reviews[:max_reviews]


def extract_reviews_from_html(page_html: str, *, slug: str, max_reviews: int) -> list[dict[str, Any]]:
    lines = html_to_lines(page_html)
    review_urls = extract_review_urls(page_html, slug)
    reviews: list[dict[str, Any]] = []
    current_author: str | None = None
    current_lines: list[str] = []
    current_like_count: int | None = None
    current_rating_value: float | None = None
    review_index = 0

    def flush_current() -> None:
        nonlocal current_author, current_lines, current_like_count, current_rating_value, review_index
        if current_author is None:
            return
        cleaned_lines = [line for line in current_lines if not is_metadata_line(line)]
        text = normalize_whitespace(" ".join(cleaned_lines))
        if text:
            review_url = review_urls[review_index] if review_index < len(review_urls) else ""
            reviews.append(
                {
                    "author": current_author,
                    "text": text,
                    "url": review_url,
                    "like_count": current_like_count,
                    "rating_value": current_rating_value,
                }
            )
            review_index += 1
        current_author = None
        current_lines = []
        current_like_count = None
        current_rating_value = None

    for line in lines:
        watched_match = WATCHED_BY_PATTERN.match(line)
        review_match = REVIEW_BY_PATTERN.match(line)
        if watched_match or review_match:
            flush_current()
            match = watched_match or review_match
            assert match is not None
            current_author = normalize_whitespace(match.group("author"))
            continue
        rating_value, like_count = parse_rating_line(line)
        if rating_value is not None:
            current_rating_value = rating_value
            current_like_count = like_count
            continue
        if current_author is None:
            continue
        if line.startswith(SKIP_LINE_PREFIXES):
            flush_current()
            if len(reviews) >= max_reviews:
                break
            continue
        current_lines.append(line)
        if len(reviews) >= max_reviews:
            break

    flush_current()
    reviews = reviews[:max_reviews]
    if reviews:
        return reviews
    return extract_reviews_from_html_fallback(page_html, slug=slug, max_reviews=max_reviews)


def trim_quote_text(text: str, *, limit: int = 180) -> str:
    normalized = normalize_whitespace(text).strip().strip('"')
    if len(normalized) <= limit:
        return normalized
    trimmed = normalized[: limit - 1].rsplit(" ", 1)[0].rstrip(" ,;:.")
    return f"{trimmed}…"


def summary_fragment(text: str, *, limit: int = 90) -> str:
    normalized = trim_quote_text(text, limit=limit)
    return normalized.strip().strip('"')

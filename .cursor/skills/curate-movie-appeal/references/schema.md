# Schema

## Source file

`Data/movie-appeal-source.json` is a JSON object keyed by movie slug.

```json
{
  "movie-slug": {
    "summary": "string",
    "appeal_tags": ["string"],
    "good_pick_if": "string",
    "maybe_skip_if": "string",
    "confidence": "high | medium | low",
    "source_quotes": [
      {
        "text": "string",
        "source": "Letterboxd review by Example",
        "url": "https://..."
      }
    ]
  }
}
```

## Runtime file

`Sources/TMNLCore/Resources/movie-appeal.json` uses the same slug-keyed shape after validation and normalization.

## Seed file

`Data/movie-appeal-seed-slugs.json` has two fields:

```json
{
  "eligibility_mode": "strict | missing-runtime-fallback",
  "lanes": [
    {
      "name": "comedy",
      "genres": ["Comedy"],
      "slugs": ["example-slug"]
    }
  ],
  "ordered_slugs": ["example-slug"]
}
```

`ordered_slugs` is the batching order. Use five batches of 10 in sequence.

## Enforced limits

- `summary` is required and must be 1-420 characters.
- `summary` must include at least one quoted fragment from a real user quote.
- `appeal_tags` is optional. If present, it must contain 1-3 tags.
- Each tag must be 2-4 words.
- `good_pick_if` is optional and must be 1-120 characters when present.
- `maybe_skip_if` is optional and must be 1-120 characters when present.
- `confidence` is optional and must be `high`, `medium`, or `low`.
- `source_quotes` is required in the reviewed source file and is not emitted into the runtime sidecar.
- `source_quotes` must contain 1-3 items.
- Each quote item must include `text`, `source`, and `url`.

## Fallback rules

- Summary-only entries are valid.
- Missing `movie-appeal.json` is non-fatal at runtime.
- Invalid source data should fail the build script instead of silently emitting partial output.

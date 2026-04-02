# ADR-005: Semantic Date Input with Natural Language Parser

**Status:** Accepted
**Date:** 2026-04-02

## Context

The current poll creation form requires users to pick start/end dates with date pickers. This is functional but not intuitive; most users think in terms like "next week" or "this weekend, evenings." We want a composable natural-language text input that resolves to concrete date ranges and time patterns.

## Decision

Replace the date picker pair and time-of-day toggles with a single text input that parses semantic tokens. A new pure Elixir module (`Oggi.DateParser`) handles parsing; the LiveView provides real-time feedback via `phx-change`.

### Grammar

Input is composed of two optional parts: a **when** token and a **time** token (in any order).

**When tokens** (date ranges, relative to today, using remaining days only):

| Token (EN) | Resolution |
|---|---|
| tomorrow | tomorrow only |
| this week | today through end of current week (Sunday) |
| next week | next Monday through next Sunday |
| this weekend | coming Saturday + Sunday |
| next weekend | Saturday + Sunday of next week |

**Time tokens** (time-of-day patterns, reuses existing SlotGenerator windows):

| Token (EN) | Pattern |
|---|---|
| morning | :morning (08:00-12:00) |
| afternoon | :afternoon (12:00-18:00) |
| evening | :evening (18:00-22:00) |

Multiple time tokens can be combined: "next week morning evening" selects both morning and evening slots.

**Defaults:**
- No when token: defaults to "this week"
- No time token: defaults to all three (morning + afternoon + evening)

### Token Dictionaries

Each locale has a map of `%{string => atom}` for token recognition. Matching is case-insensitive. Multi-word tokens (e.g. "next week", "prossima settimana") are matched greedily (longest match first).

Supported locales: en, it, fr, de, es.

### Parser Module: `Oggi.DateParser`

```elixir
# Input
DateParser.parse("prossima settimana sera", :it, ~D[2026-04-02])

# Output
{:ok, %{
  date_range: {~D[2026-04-06], ~D[2026-04-12]},
  patterns: [:evening],
  tokens: [
    %{text: "prossima settimana", kind: :when, value: :next_week},
    %{text: "sera", kind: :time, value: :evening}
  ],
  unrecognized: []
}}

# On partial/empty input
DateParser.parse("", :it, ~D[2026-04-02])
# => {:ok, %{date_range: {~D[2026-04-02], ~D[2026-04-06]}, patterns: [:morning, :afternoon, :evening], ...}}

# On unrecognized tokens
DateParser.parse("next week brunch", :en, ~D[2026-04-02])
# => {:ok, %{..., unrecognized: ["brunch"]}}
```

The module is **pure** (no DB, no side effects). It takes the current date as a parameter for testability.

### Date Resolution Logic

All ranges use "remaining days" logic:

- **this week**: `max(today, Monday)` to Sunday. If today is Sunday, just Sunday.
- **next week**: next Monday to next Sunday (always full 7 days).
- **tomorrow**: tomorrow to tomorrow.
- **this weekend**: coming Saturday to Sunday. If today is Saturday, Saturday to Sunday. If today is Sunday, just Sunday.
- **next weekend**: Saturday to Sunday of next week.

Week starts on Monday (European convention, consistent with existing dd/mm/yyyy format).

### LiveView Changes (`PollLive.New`)

1. Replace date picker pair + time-of-day toggles with a single text input field
2. On each `phx-change`, call `DateParser.parse/3` and update assigns:
   - `@parsed` -- the parse result (tokens, date_range, patterns, unrecognized)
   - `@preview_slots` -- generated via `SlotGenerator.generate/3` for preview count
3. Below the input, render:
   - **Recognized chips**: one per parsed token, showing the localized text
   - **Slot preview**: "12 slots from Mon 7 Apr to Sun 12 Apr" (localized)
   - **Guidance**: if `unrecognized` is non-empty, show hint text
   - **Placeholder**: locale-aware example (e.g. "prossima settimana sera" for Italian)

The hidden fields `date_range_start`, `date_range_end` are populated from the parse result on submit. The `patterns` assign is populated from parsed time tokens. No schema changes needed; `Poll` still stores concrete dates.

### Error Handling

- Completely unrecognized input: fall back to defaults (this week, all patterns), show guidance
- The parser never returns an error tuple; it always produces a best-effort result with `unrecognized` tokens listed

## Edge Cases

- **Input in wrong locale**: tokens won't match; falls back to defaults with all input in `unrecognized`. Guidance nudges user.
- **"This weekend" on a Monday**: resolves to coming Saturday-Sunday (5 days away).
- **"This week" on a Sunday**: resolves to just Sunday.
- **"Tomorrow" on last day of range**: works fine, just one day.
- **Mixed locale tokens**: each token matched independently against current locale dictionary.

## Consequences

- **Simpler UX**: one text field replaces three inputs (date start, date end, time toggles)
- **No external deps**: pure Elixir pattern matching with token dictionaries
- **Extensible**: adding new ranges (e.g. "next 3 days") is just a new dictionary entry + resolution function
- **No schema changes**: parser output maps directly to existing `date_range_start`, `date_range_end`, and `patterns` fields
- **Testable**: pure function with injected date; test every locale and edge case without mocking

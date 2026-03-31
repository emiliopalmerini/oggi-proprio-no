# ADR-002: Multi-Lingual Copy via Gettext + Accept-Language Detection

**Status:** Accepted
**Date:** 2026-03-31

## Context

All ~30 user-facing strings are hardcoded in English across `poll_live/new.ex`, `poll_live/show.ex`, and `core_components.ex`. The app name is Italian ("Oggi Proprio No") and targets a multilingual audience. We want automatic locale detection with no manual switcher.

## Decision

Use Phoenix's standard Gettext integration with `Accept-Language` header detection.

### Supported locales

| Locale  | Language          |
|---------|-------------------|
| `en_US` | English (US)      |
| `en_GB` | English (GB)      |
| `fr`    | French            |
| `de`    | German            |
| `it`    | Italian           |
| `es`    | Spanish           |

**Default/fallback:** `en_US` (also used when browser sends generic `en`).

### Architecture

1. **Dependency**: Add `{:gettext, "~> 0.26"}` to `mix.exs`.
2. **Gettext backend**: Create `OggiWeb.Gettext` module.
3. **Plug**: Add a plug in the `:browser` pipeline that:
   - Parses the `Accept-Language` header.
   - Maps it to the best matching supported locale (e.g. `en` → `en_US`, `en-GB` → `en_GB`).
   - Calls `Gettext.put_locale/2`.
   - Sets `@locale` assign for the root layout (dynamic `<html lang="...">`).
4. **String extraction**: Wrap all user-facing strings in `gettext()` / `pgettext()` macros.
5. **Translation files**: `priv/gettext/{locale}/LC_MESSAGES/default.po` for each locale.
6. **Dynamic `lang` attribute**: Root layout reads `@locale` assign to set `<html lang={@locale}>`.

### Locale resolution rules

1. Parse `Accept-Language` header into a quality-sorted list.
2. For each candidate, try exact match against supported locales (normalizing `en-US` → `en_US`).
3. If no exact match, try language-only prefix (e.g. `fr-CA` → `fr`).
4. Special case: bare `en` → `en_US`.
5. If no match at all → `en_US`.

### Inputs

- `Accept-Language` HTTP header (e.g. `it,en-US;q=0.9,en;q=0.8`)

### Outputs

- `Gettext.put_locale/2` called with matched locale
- `@locale` assign available in root layout
- All UI strings rendered in the detected language

### Edge cases

- **Missing header**: Falls back to `en_US`.
- **Unsupported language** (e.g. `ja`): Falls back to `en_US`.
- **Regional variant without specific support** (e.g. `fr-CA`): Falls back to `fr`.
- **`en` without region**: Resolves to `en_US`.
- **`en-GB`**: Resolves to `en_GB` (distinct translations for British English).
- **Multiple languages at equal quality**: First in header order wins.

### What is NOT in scope

- Manual language switcher / cookie persistence.
- Database-stored locale preference.
- Pluralization rules beyond what Gettext provides out of the box.
- Date/number formatting (handled separately by `lang="it"` → browser native formatting, or a future ADR).

## Consequences

- Every new user-facing string must be wrapped in `gettext()`.
- Adding a new locale requires only a new `.po` file — no code changes.
- `mix gettext.extract` keeps `.pot` templates in sync with source.
- `en_US` `.po` file is technically optional (source strings are already English) but we create it for consistency with `en_GB` overrides.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this?

"Oggi Proprio No" ("today I really can't") is a constraint-elimination appointment scheduler. Organizers create time slots, participants mark when they **can't** attend, the system picks the first conflict-free slot. Real-time updates via Phoenix PubSub.

## Commands

```bash
mix setup                  # Full first-time setup (deps, DB, assets)
mix phx.server             # Dev server at localhost:4000
mix test                   # Run all tests (creates/migrates DB automatically)
mix test path/to/test.exs  # Run a single test file
mix test path/to/test.exs:42  # Run a specific test by line number
mix precommit              # compile --warnings-as-errors, unused deps, format, test
mix format                 # Format all Elixir files
mix ecto.reset             # Drop and recreate DB
```

Dev environment uses Nix flake; enter with `nix develop`.

## Architecture

**Elixir/Phoenix LiveView** app with **SQLite** (ecto_sqlite3), **Tailwind CSS v4** + **daisyUI** theme, and **Gettext** i18n (it, en, fr, de, es).

### Domain layer (`lib/oggi/`)

- `polls.ex` -- Polls context; public API for all poll operations (create, join, vote, close)
- `polls/` -- Ecto schemas: Poll, Slot, Participant, Unavailability (all binary_id PKs)
- `slot_generator.ex` -- Pure function; generates time slots from availability patterns (morning/afternoon/evening + custom)
- `polls/cleaner.ex` -- GenServer; auto-deletes stale polls every 24h

### Web layer (`lib/oggi_web/`)

- `router.ex` -- Two routes: `/` (new poll), `/p/:token` (show poll)
- `live/poll_live/new.ex` -- LiveView for poll creation form
- `live/poll_live/show.ex` -- LiveView for poll view (admin + participant, real-time calendar grid)
- `plugs/set_locale.ex` -- Extracts locale from Accept-Language header
- `components/core_components.ex` -- Shared UI components (button, input, icon, flash)

### Key design decisions

- **Token-based auth, no accounts**: each poll has admin_token and participant_token; organizer shares participant link
- **Constraint elimination**: participants mark unavailability (not availability); system finds first slot with zero conflicts
- **Real-time**: PubSub broadcasts on vote; all browsers refresh state without page reload
- **ADRs in `docs/adr/`** define specs before implementation

## Development workflow

Follow TDD: acceptance tests -> context tests -> unit tests -> implementation. Write an ADR in `docs/adr/` before starting new features. See AGENTS.md for full project guidelines.

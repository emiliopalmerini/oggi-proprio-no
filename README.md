# Oggi Proprio No

> "today I really can't"

A constraint-elimination appointment scheduler. An organizer creates time slots, participants mark when they **can't** attend, and the system picks the first slot where everyone is free.

## How it works

1. **Organizer** creates a poll: picks a date range, time windows (morning/afternoon/evening), and meeting duration
2. **Participants** get a link, join, and tap the slots they **can't** make
3. **Organizer** closes the poll -- the system finds the earliest slot with no conflicts

Real-time updates: when someone votes, everyone sees it instantly.

## Tech stack

- **Elixir** + **Phoenix LiveView** -- real-time UI over WebSocket, no JS framework
- **SQLite** via `ecto_sqlite3` -- zero-config database
- **Tailwind CSS** + **DaisyUI** -- warm terracotta theme
- **Nix flake** for reproducible dev environment

## Getting started

```bash
# Enter the dev shell (installs Elixir, Erlang, SQLite)
nix develop

# First time setup
mix deps.get
mix ecto.setup

# Run the app
mix phx.server
```

Then visit [localhost:4000](http://localhost:4000).

## Running tests

```bash
mix test
```

28 tests covering unit (slot generation), context (polls CRUD), and acceptance (full LiveView flow).

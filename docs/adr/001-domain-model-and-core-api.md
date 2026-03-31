# ADR-001: Domain Model and Core API

**Status:** Accepted
**Date:** 2026-03-31

## Context

"Oggi Proprio No" is a constraint-elimination appointment scheduler. An organizer defines candidate time slots via recurring patterns within a date range. Participants mark when they are **not** available. The system picks the first slot where no one is unavailable.

Single release, zero infrastructure. Just `mix phx.server` (dev) or a release binary (prod).

## Domain Model

### Poll

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| title | string | e.g. "Team sync", "Dinner" |
| description | string | Optional details |
| meeting_duration | duration | e.g. 1h, 30m, 2h |
| date_range_start | date | Start of candidate range |
| date_range_end | date | End of candidate range |
| admin_token | string | Secret token for organizer link |
| participant_token | string | Secret token for participant link |
| status | enum | `open`, `closed`, `resolved` |
| created_at | timestamp | |

### Availability Pattern

Recurring patterns defined by the organizer, expanded into concrete slots.

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| poll_id | UUID | FK to Poll |
| kind | enum | `morning`, `afternoon`, `evening`, `custom` |
| days_of_week | []int | 0=Sun..6=Sat. Empty = every day |
| custom_start | time | Only for `custom` kind |
| custom_end | time | Only for `custom` kind |

Predefined windows:
- **morning**: 08:00 - 12:00
- **afternoon**: 12:00 - 18:00
- **evening**: 18:00 - 22:00

### Slot

Concrete time slot generated from patterns + date range + duration.

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| poll_id | UUID | FK to Poll |
| start_time | datetime | |
| end_time | datetime | |

Unique constraint on (poll_id, start_time) to deduplicate overlapping patterns.

### Participant

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| poll_id | UUID | FK to Poll |
| name | string | Display name |
| is_organizer | bool | True for the poll creator |

### Unavailability

A participant marks a slot as unavailable.

| Field | Type | Description |
|---|---|---|
| participant_id | UUID | Composite PK, FK to Participant |
| slot_id | UUID | Composite PK, FK to Slot |

## Slot Generation

```
for each day in [date_range_start, date_range_end]:
  for each pattern in poll.patterns:
    if days_of_week is not empty AND day.weekday not in days_of_week:
      skip
    window_start = day + pattern.start_time
    window_end = day + pattern.end_time
    cursor = window_start
    while cursor + meeting_duration <= window_end:
      create Slot(start=cursor, end=cursor+meeting_duration)
      cursor += meeting_duration
```

## Resolution

When the organizer closes the poll:

```
slots = poll.slots ORDER BY start_time ASC
for each slot:
  if count(unavailabilities for slot) == 0:
    return slot  // first fully-available slot
return nil  // no slot works
```

## Routes (LiveView)

No REST API needed - LiveView handles everything over WebSocket.

| Path | Description |
|---|---|
| `/` | Home - create a new poll |
| `/p/:admin_token` | Organizer view (manage, vote, close) |
| `/p/:participant_token` | Participant view (join, vote) |

All interactions (creating polls, toggling unavailabilities, closing) happen via LiveView events. When a participant votes, all other connected browsers update in real-time via PubSub.

## Auth

No accounts. Two link-based tokens per poll:
- **Admin link** (`/p/:admin_token`): full control + vote
- **Participant link** (`/p/:participant_token`): join + vote
- Organizer shares the participant link. Keeps admin link private.

## Tech Stack

- **Elixir** + **Phoenix Framework**
- **Phoenix LiveView** for real-time UI (replaces HTMX + Alpine)
- **SQLite** via `ecto_sqlite3`
- **Tailwind CSS** (bundled with Phoenix by default)

## Edge Cases

- **No valid slot**: report "no common availability". Organizer can create new poll.
- **Overlapping patterns**: deduplicated via unique constraint on (poll_id, start_time).
- **Duration > window**: no slots generated, validation error.
- **Empty date range**: validation error.
- **Participant joins late**: sees all slots, existing votes preserved.

## Out of Scope

- Timezone handling (single timezone assumed)
- Notifications
- Calendar integrations
- User accounts

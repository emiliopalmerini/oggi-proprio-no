# ADR-004: Auto-Cleanup of Resolved and Closed Polls

**Status:** Accepted
**Date:** 2026-04-01

## Context

Polls persist in the database indefinitely. Over time, resolved and closed polls accumulate with no purpose. We need a lightweight cleanup mechanism.

## Decision

Add a `GenServer` (`Oggi.Polls.Cleaner`) that runs once every 24 hours and deletes stale polls:

- **Resolved polls**: delete 7 days after the `resolved_slot.end_time`
- **Closed (unresolved) polls**: delete 7 days after `date_range_end`
- **Open polls**: untouched

### Inputs
- Current datetime (for testability, injected via argument)

### Outputs
- `{:ok, deleted_count}` for the cleanup function

### Behavior
1. On application start, the GenServer schedules the first cleanup after `@interval` (24h)
2. On each `:cleanup` tick, it calls `Oggi.Polls.delete_stale_polls/0`
3. After execution, it schedules the next tick
4. Cascade deletes handle slots, participants, and unavailabilities

### Edge Cases
- App restarts: timer resets, worst case cleanup is delayed up to 24h — acceptable
- No stale polls: query returns 0 deletes, no-op
- DB errors: GenServer logs the error and schedules next tick (no crash)

### Query Logic
```sql
DELETE FROM polls
WHERE (status = 'resolved' AND resolved_slot.end_time < now() - 7 days)
   OR (status = 'closed' AND date_range_end < now() - 7 days)
```

## Consequences

- Old data is cleaned up automatically
- Zero external dependencies (no Oban)
- If the GenServer crashes, the supervisor restarts it and cleanup resumes next interval

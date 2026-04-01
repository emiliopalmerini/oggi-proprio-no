# ADR-003: Participant Landing Page (Join-First UX)

**Status:** Accepted
**Date:** 2026-04-01

## Context

Currently, when a participant clicks the poll link they see the calendar grid immediately alongside a small join form. This is disorienting — they don't know what they're looking at before committing. We want a two-step flow: first understand and join, then interact with the calendar.

## Decision

Change `PollLive.Show` so the participant view has two states:

### 1. Pre-join landing (participant, not yet joined, poll open)

Full-page card with:
- Poll title and organizer name
- Poll details: date range, meeting duration, number of participants already in
- Explanation of the mechanic: "mark slots when you are NOT available"
- Join form (name input + button)

The calendar grid, legend, and participants list are **hidden**.

### 2. Post-join (participant joined, or admin, or poll closed/resolved)

Current view: calendar grid, legend, participants list, admin controls.

### 3. Closed/resolved poll, visitor not joined

Show the resolved/closed banner with the result (or "no slot found"). No join form, no calendar.

### Scope

- Only the `render/1` function in `PollLive.Show` changes (template-level conditionals)
- No new LiveView, no new route, no schema changes
- Gettext strings added for new copy

## Inputs

- `@role` — `:admin` | `:participant`
- `@participant` — `nil` if not joined
- `@poll.status` — `:open` | `:closed` | `:resolved`

## Outputs

| role | participant | status | view |
|------|------------|--------|------|
| admin | always set | any | full calendar (current behavior) |
| participant | nil | open | landing page + join form |
| participant | nil | closed/resolved | result banner only |
| participant | set | any | full calendar (current behavior) |

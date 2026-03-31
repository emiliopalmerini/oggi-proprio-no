This is "Oggi Proprio No", a constraint-elimination appointment scheduler built with Phoenix LiveView.

## Project structure

- `lib/oggi/` - Domain layer (contexts, schemas, pure logic)
  - `polls.ex` - Polls context (public API: create, join, vote, close)
  - `polls/` - Ecto schemas (Poll, Slot, Participant, Unavailability)
  - `slot_generator.ex` - Pure function: generates time slots from patterns
- `lib/oggi_web/` - Web layer (LiveViews, components, router)
  - `live/poll_live/new.ex` - Create poll form
  - `live/poll_live/show.ex` - Poll view (admin + participant, calendar grid)
- `docs/adr/` - Architecture Decision Records
- `test/` - ExUnit tests (unit, context, acceptance)

## Project guidelines

- Follow TDD: acceptance tests -> context tests -> unit tests -> implementation
- ADRs in `docs/adr/` define specs before implementation
- Use idiomatic Elixir: guard clauses, pattern matching, multiple function clauses
- Dates use dd/mm/yyyy format (European convention)

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `OggiWeb.Layouts` module is aliased in `oggi_web.ex`
- **Always** use the imported `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex`

### JS and CSS guidelines

- **Use Tailwind CSS classes** with the warm terracotta/Italian DaisyUI theme defined in `app.css`
- Tailwindcss v4 uses import syntax in `app.css` (no tailwind.config.js)
- **Never** use `@apply` when writing raw CSS
- **Never write inline `<script>` tags** in templates, use colocated JS hooks instead
- Out of the box only `app.js` and `app.css` bundles are supported

### Elixir guidelines

- Elixir lists do not support index-based access -- use `Enum.at`, pattern matching, or `List`
- **Never** nest multiple modules in the same file
- **Never** use map access syntax (`changeset[:field]`) on structs -- use `my_struct.field`
- Use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Predicate function names end in `?`, don't start with `is_`

### LiveView guidelines

- **Never** use deprecated `live_redirect`/`live_patch` -- use `push_navigate`/`push_patch`
- **Avoid LiveComponents** unless strongly needed
- **Always** use `to_form/2` and `<.form for={@form}>` pattern
- Use LiveView streams for collections to avoid memory issues
- Real-time updates via `Phoenix.PubSub` broadcast/subscribe pattern

### Test guidelines

- Use `Phoenix.LiveViewTest` for LiveView tests
- **Always** reference key element IDs in tests
- Focus on testing outcomes, not implementation details

defmodule Oggi.DateParser do
  @moduledoc """
  Parses natural-language date/time input into concrete date ranges and time patterns.
  Pure logic, no database, no side effects.
  """

  @default_patterns [:morning, :afternoon, :evening]

  @dictionaries %{
    en: %{
      when: [
        {"next weekend", :next_weekend},
        {"this weekend", :this_weekend},
        {"next week", :next_week},
        {"this week", :this_week},
        {"tomorrow", :tomorrow}
      ],
      time: [
        {"morning", :morning},
        {"afternoon", :afternoon},
        {"evening", :evening}
      ]
    },
    it: %{
      when: [
        {"prossimo fine settimana", :next_weekend},
        {"questo fine settimana", :this_weekend},
        {"prossima settimana", :next_week},
        {"questa settimana", :this_week},
        {"domani", :tomorrow}
      ],
      time: [
        {"mattina", :morning},
        {"pomeriggio", :afternoon},
        {"sera", :evening}
      ]
    },
    fr: %{
      when: [
        {"week-end prochain", :next_weekend},
        {"ce week-end", :this_weekend},
        {"semaine prochaine", :next_week},
        {"cette semaine", :this_week},
        {"demain", :tomorrow}
      ],
      time: [
        {"matin", :morning},
        {"après-midi", :afternoon},
        {"soir", :evening}
      ]
    },
    de: %{
      when: [
        {"nächstes wochenende", :next_weekend},
        {"dieses wochenende", :this_weekend},
        {"nächste woche", :next_week},
        {"diese woche", :this_week},
        {"morgen", :tomorrow}
      ],
      time: [
        {"vormittag", :morning},
        {"nachmittag", :afternoon},
        {"abend", :evening}
      ]
    },
    es: %{
      when: [
        {"próximo fin de semana", :next_weekend},
        {"este fin de semana", :this_weekend},
        {"próxima semana", :next_week},
        {"esta semana", :this_week},
        {"mañana", :tomorrow}
      ],
      time: [
        {"mañana", :morning},
        {"tarde", :afternoon},
        {"noche", :evening}
      ]
    }
  }

  def parse(input, locale, today) do
    dictionary = Map.get(@dictionaries, locale, @dictionaries.en)
    normalized = normalize(input)

    {remaining, when_tokens} = extract_tokens(normalized, dictionary.when, :when)
    {remaining, time_tokens} = extract_tokens(remaining, dictionary.time, :time)

    unrecognized =
      remaining
      |> String.split(~r/\s+/, trim: true)

    when_value = List.first(when_tokens)
    date_range = resolve_date_range(when_value, today)
    patterns = Enum.map(time_tokens, & &1.value)

    tokens =
      Enum.map(when_tokens ++ time_tokens, fn token ->
        %{text: token.text, kind: token.kind, value: token.value}
      end)

    {:ok,
     %{
       date_range: date_range,
       patterns: if(patterns == [], do: @default_patterns, else: patterns),
       tokens: tokens,
       unrecognized: unrecognized
     }}
  end

  defp normalize(input) do
    input
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end

  defp extract_tokens(input, entries, kind) do
    Enum.reduce(entries, {input, []}, fn {text, value}, {remaining, found} ->
      downcased = String.downcase(text)

      if String.contains?(remaining, downcased) do
        new_remaining = String.replace(remaining, downcased, "", global: false) |> String.trim()
        token = %{text: text, kind: kind, value: value}
        {new_remaining, found ++ [token]}
      else
        {remaining, found}
      end
    end)
  end

  defp resolve_date_range(nil, today), do: resolve_when(:this_week, today)
  defp resolve_date_range(token, today), do: resolve_when(token.value, today)

  defp resolve_when(:this_week, today) do
    # Monday-based week; remaining days through Sunday
    day_of_week = Date.day_of_week(today, :monday)
    sunday = Date.add(today, 7 - day_of_week)
    {today, sunday}
  end

  defp resolve_when(:next_week, today) do
    day_of_week = Date.day_of_week(today, :monday)
    next_monday = Date.add(today, 8 - day_of_week)
    next_sunday = Date.add(next_monday, 6)
    {next_monday, next_sunday}
  end

  defp resolve_when(:tomorrow, today) do
    tomorrow = Date.add(today, 1)
    {tomorrow, tomorrow}
  end

  defp resolve_when(:this_weekend, today) do
    day_of_week = Date.day_of_week(today, :monday)

    cond do
      # Sunday
      day_of_week == 7 -> {today, today}
      # Saturday
      day_of_week == 6 -> {today, Date.add(today, 1)}
      # Weekday: jump to Saturday
      true ->
        saturday = Date.add(today, 6 - day_of_week)
        {saturday, Date.add(saturday, 1)}
    end
  end

  defp resolve_when(:next_weekend, today) do
    day_of_week = Date.day_of_week(today, :monday)
    # Next week's Saturday = days until next Monday + 5
    next_saturday = Date.add(today, 8 - day_of_week + 5)
    {next_saturday, Date.add(next_saturday, 1)}
  end
end

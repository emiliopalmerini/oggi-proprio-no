defmodule Oggi.DateParser do
  @moduledoc """
  Parses natural-language date/time input into concrete date ranges and time patterns.
  Pure logic, no database, no side effects.
  """

  @default_patterns [:morning, :afternoon, :evening]

  @next_prefixes %{
    en: "next",
    it: "prossimo",
    fr: "prochain",
    de: "nächsten",
    es: "próximo"
  }

  @day_names %{
    en: %{
      "monday" => 1,
      "tuesday" => 2,
      "wednesday" => 3,
      "thursday" => 4,
      "friday" => 5,
      "saturday" => 6,
      "sunday" => 7
    },
    it: %{
      "lunedì" => 1,
      "lunedi" => 1,
      "martedì" => 2,
      "martedi" => 2,
      "mercoledì" => 3,
      "mercoledi" => 3,
      "giovedì" => 4,
      "giovedi" => 4,
      "venerdì" => 5,
      "venerdi" => 5,
      "sabato" => 6,
      "domenica" => 7
    },
    fr: %{
      "lundi" => 1,
      "mardi" => 2,
      "mercredi" => 3,
      "jeudi" => 4,
      "vendredi" => 5,
      "samedi" => 6,
      "dimanche" => 7
    },
    de: %{
      "montag" => 1,
      "dienstag" => 2,
      "mittwoch" => 3,
      "donnerstag" => 4,
      "freitag" => 5,
      "samstag" => 6,
      "sonntag" => 7
    },
    es: %{
      "lunes" => 1,
      "martes" => 2,
      "miércoles" => 3,
      "miercoles" => 3,
      "jueves" => 4,
      "viernes" => 5,
      "sábado" => 6,
      "sabado" => 6,
      "domingo" => 7
    }
  }

  # Numeric range prefixes (all gender/plural forms of "next")
  @numeric_prefixes %{
    en: ~w(next),
    it: ~w(prossimi prossime prossimo prossima),
    fr: ~w(prochains prochaines prochain prochaine),
    de: ~w(nächste nächsten nächstes),
    es: ~w(próximos próximas próximo próxima)
  }

  # Unit words mapped to range type (singular and plural)
  @unit_words %{
    en: %{
      "day" => :days,
      "days" => :days,
      "week" => :weeks,
      "weeks" => :weeks,
      "month" => :months,
      "months" => :months,
      "weekend" => :weekends,
      "weekends" => :weekends
    },
    it: %{
      "giorno" => :days,
      "giorni" => :days,
      "settimana" => :weeks,
      "settimane" => :weeks,
      "mese" => :months,
      "mesi" => :months,
      "fine settimana" => :weekends
    },
    fr: %{
      "jour" => :days,
      "jours" => :days,
      "semaine" => :weeks,
      "semaines" => :weeks,
      "mois" => :months,
      "week-end" => :weekends,
      "week-ends" => :weekends
    },
    de: %{
      "tag" => :days,
      "tage" => :days,
      "woche" => :weeks,
      "wochen" => :weeks,
      "monat" => :months,
      "monate" => :months,
      "wochenende" => :weekends,
      "wochenenden" => :weekends
    },
    es: %{
      "día" => :days,
      "días" => :days,
      "dia" => :days,
      "dias" => :days,
      "semana" => :weeks,
      "semanas" => :weeks,
      "mes" => :months,
      "meses" => :months,
      "fin de semana" => :weekends,
      "fines de semana" => :weekends
    }
  }

  @dictionaries %{
    en: %{
      when: [
        {"next weekend", :next_weekend},
        {"this weekend", :this_weekend},
        {"next month", :next_month},
        {"this month", :this_month},
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
        {"prossimo mese", :next_month},
        {"questo mese", :this_month},
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
        {"mois prochain", :next_month},
        {"ce mois", :this_month},
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
        {"nächsten monat", :next_month},
        {"diesen monat", :this_month},
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
        {"próximo mes", :next_month},
        {"este mes", :this_month},
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

    # Second pass: try numeric range (e.g. "next 3 weeks")
    {remaining, numeric_token} = extract_numeric_range(remaining, locale, today)

    # Third pass: try day-of-week resolution on remaining text
    {remaining, day_token} = extract_day_of_week(remaining, locale, today)

    all_when_tokens = when_tokens ++ numeric_token ++ day_token

    unrecognized =
      remaining
      |> String.split(~r/\s+/, trim: true)

    when_value = List.first(all_when_tokens)
    date_range = resolve_date_range(when_value, today)
    patterns = Enum.map(time_tokens, & &1.value)

    tokens =
      Enum.map(all_when_tokens ++ time_tokens, fn token ->
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

  defp extract_numeric_range(remaining, locale, today) do
    prefixes = Map.get(@numeric_prefixes, locale, @numeric_prefixes.en)
    units = Map.get(@unit_words, locale, @unit_words.en)

    # Sort unit phrases longest-first for greedy matching
    sorted_units = units |> Map.keys() |> Enum.sort_by(&(-String.length(&1)))

    # Try to match: <prefix> <number> <unit>
    Enum.find_value(prefixes, {remaining, []}, fn prefix ->
      Enum.find_value(sorted_units, fn unit_text ->
        pattern = "#{prefix} " <> "(\\d+) " <> Regex.escape(unit_text)

        case Regex.run(~r/#{pattern}/i, remaining) do
          [full_match, n_str] ->
            n = String.to_integer(n_str)
            unit = Map.fetch!(units, unit_text)
            date_range = resolve_numeric_range(unit, n, today)
            token_text = "#{prefix} #{n} #{unit_text}"
            new_remaining = String.replace(remaining, full_match, "") |> String.trim()
            token = [%{text: token_text, kind: :when, value: {:numeric, date_range}}]
            {new_remaining, token}

          _ ->
            nil
        end
      end)
    end)
  end

  defp resolve_numeric_range(:days, n, today) do
    {today, Date.add(today, n - 1)}
  end

  defp resolve_numeric_range(:weeks, n, today) do
    {today, Date.add(today, n * 7 - 1)}
  end

  defp resolve_numeric_range(:months, n, today) do
    # "next N months" = today through end of the Nth month (counting current month as 1st)
    end_date =
      Enum.reduce(1..(n - 1)//1, today, fn _, acc ->
        acc |> Date.end_of_month() |> Date.add(1)
      end)
      |> Date.end_of_month()

    {today, end_date}
  end

  defp resolve_numeric_range(:weekends, n, today) do
    day_of_week = Date.day_of_week(today, :monday)

    first_saturday =
      cond do
        day_of_week == 6 -> today
        day_of_week == 7 -> Date.add(today, 6)
        true -> Date.add(today, 6 - day_of_week)
      end

    last_sunday = first_saturday |> Date.add(1 + (n - 1) * 7)
    {first_saturday, last_sunday}
  end

  defp extract_day_of_week(remaining, locale, today) do
    day_map = Map.get(@day_names, locale, @day_names.en)
    next_prefix = Map.get(@next_prefixes, locale, "next")
    words = String.split(remaining, ~r/\s+/, trim: true)

    {has_next, words_without_next} =
      if next_prefix in words do
        {true, List.delete(words, next_prefix)}
      else
        {false, words}
      end

    case find_day_name(words_without_next, day_map) do
      {day_word, target_dow} ->
        date = resolve_day_of_week(target_dow, has_next, today)
        token_text = if has_next, do: "#{next_prefix} #{day_word}", else: day_word
        token = [%{text: token_text, kind: :when, value: {:day, date}}]

        leftover =
          words_without_next
          |> List.delete(day_word)
          |> Enum.join(" ")

        {leftover, token}

      nil when has_next ->
        # "next" was consumed but no day found; put it back
        {remaining, []}

      nil ->
        {remaining, []}
    end
  end

  defp find_day_name(words, day_map) do
    Enum.find_value(words, fn word ->
      case Map.get(day_map, word) do
        nil -> nil
        dow -> {word, dow}
      end
    end)
  end

  defp resolve_day_of_week(target_dow, has_next, today) do
    current_dow = Date.day_of_week(today, :monday)
    days_ahead = rem(target_dow - current_dow + 7, 7)

    days_ahead =
      if has_next do
        days_ahead + 7
      else
        # Same day = today; past day = next week
        days_ahead
      end

    Date.add(today, days_ahead)
  end

  defp resolve_date_range(nil, today), do: resolve_when(:this_week, today)
  defp resolve_date_range(%{value: {:day, date}}, _today), do: {date, date}
  defp resolve_date_range(%{value: {:numeric, date_range}}, _today), do: date_range
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

  defp resolve_when(:this_month, today) do
    end_of_month = Date.end_of_month(today)
    {today, end_of_month}
  end

  defp resolve_when(:next_month, today) do
    first_of_next = today |> Date.end_of_month() |> Date.add(1)
    end_of_next = Date.end_of_month(first_of_next)
    {first_of_next, end_of_next}
  end

  defp resolve_when(:this_weekend, today) do
    day_of_week = Date.day_of_week(today, :monday)

    cond do
      # Sunday
      day_of_week == 7 ->
        {today, today}

      # Saturday
      day_of_week == 6 ->
        {today, Date.add(today, 1)}

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

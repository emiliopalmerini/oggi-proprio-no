defmodule Oggi.DateParserTest do
  use ExUnit.Case

  alias Oggi.DateParser

  # 2026-04-02 is a Thursday
  @today ~D[2026-04-02]

  describe "when tokens" do
    test "parses 'this week' as remaining days through Sunday" do
      assert {:ok, result} = DateParser.parse("this week", :en, @today)
      assert result.date_range == {~D[2026-04-02], ~D[2026-04-05]}
    end

    test "parses 'next week' as next Monday through Sunday" do
      assert {:ok, result} = DateParser.parse("next week", :en, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
    end

    test "parses 'tomorrow'" do
      assert {:ok, result} = DateParser.parse("tomorrow", :en, @today)
      assert result.date_range == {~D[2026-04-03], ~D[2026-04-03]}
    end

    test "parses 'this weekend' as coming Saturday-Sunday" do
      assert {:ok, result} = DateParser.parse("this weekend", :en, @today)
      assert result.date_range == {~D[2026-04-04], ~D[2026-04-05]}
    end

    test "parses 'next weekend' as Saturday-Sunday of next week" do
      assert {:ok, result} = DateParser.parse("next weekend", :en, @today)
      assert result.date_range == {~D[2026-04-11], ~D[2026-04-12]}
    end
  end

  describe "time tokens" do
    test "parses 'morning' pattern" do
      assert {:ok, result} = DateParser.parse("morning", :en, @today)
      assert result.patterns == [:morning]
    end

    test "parses 'evening' pattern" do
      assert {:ok, result} = DateParser.parse("evening", :en, @today)
      assert result.patterns == [:evening]
    end

    test "parses 'afternoon' pattern" do
      assert {:ok, result} = DateParser.parse("afternoon", :en, @today)
      assert result.patterns == [:afternoon]
    end

    test "combines multiple time tokens" do
      assert {:ok, result} = DateParser.parse("morning evening", :en, @today)
      assert :morning in result.patterns
      assert :evening in result.patterns
    end
  end

  describe "composable input" do
    test "parses 'next week evening'" do
      assert {:ok, result} = DateParser.parse("next week evening", :en, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end

    test "parses 'morning this weekend'" do
      assert {:ok, result} = DateParser.parse("morning this weekend", :en, @today)
      assert result.date_range == {~D[2026-04-04], ~D[2026-04-05]}
      assert result.patterns == [:morning]
    end

    test "parses 'tomorrow morning afternoon'" do
      assert {:ok, result} = DateParser.parse("tomorrow morning afternoon", :en, @today)
      assert result.date_range == {~D[2026-04-03], ~D[2026-04-03]}
      assert :morning in result.patterns
      assert :afternoon in result.patterns
    end
  end

  describe "defaults" do
    test "empty input defaults to this week + all patterns" do
      assert {:ok, result} = DateParser.parse("", :en, @today)
      assert result.date_range == {~D[2026-04-02], ~D[2026-04-05]}
      assert result.patterns == [:morning, :afternoon, :evening]
    end

    test "only when token defaults to all patterns" do
      assert {:ok, result} = DateParser.parse("next week", :en, @today)
      assert result.patterns == [:morning, :afternoon, :evening]
    end

    test "only time token defaults to this week" do
      assert {:ok, result} = DateParser.parse("evening", :en, @today)
      assert result.date_range == {~D[2026-04-02], ~D[2026-04-05]}
    end
  end

  describe "tokens metadata" do
    test "returns recognized tokens with kind and value" do
      assert {:ok, result} = DateParser.parse("next week evening", :en, @today)

      assert %{text: "next week", kind: :when, value: :next_week} in result.tokens
      assert %{text: "evening", kind: :time, value: :evening} in result.tokens
    end

    test "returns unrecognized words" do
      assert {:ok, result} = DateParser.parse("next week brunch", :en, @today)
      assert "brunch" in result.unrecognized
    end
  end

  describe "case insensitivity" do
    test "parses uppercase input" do
      assert {:ok, result} = DateParser.parse("Next Week Evening", :en, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end
  end

  describe "Italian locale" do
    test "parses 'prossima settimana sera'" do
      assert {:ok, result} = DateParser.parse("prossima settimana sera", :it, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end

    test "parses 'questa settimana mattina'" do
      assert {:ok, result} = DateParser.parse("questa settimana mattina", :it, @today)
      assert result.date_range == {~D[2026-04-02], ~D[2026-04-05]}
      assert result.patterns == [:morning]
    end

    test "parses 'domani'" do
      assert {:ok, result} = DateParser.parse("domani", :it, @today)
      assert result.date_range == {~D[2026-04-03], ~D[2026-04-03]}
    end

    test "parses 'questo fine settimana'" do
      assert {:ok, result} = DateParser.parse("questo fine settimana", :it, @today)
      assert result.date_range == {~D[2026-04-04], ~D[2026-04-05]}
    end

    test "parses 'prossimo fine settimana'" do
      assert {:ok, result} = DateParser.parse("prossimo fine settimana", :it, @today)
      assert result.date_range == {~D[2026-04-11], ~D[2026-04-12]}
    end

    test "parses 'pomeriggio'" do
      assert {:ok, result} = DateParser.parse("pomeriggio", :it, @today)
      assert result.patterns == [:afternoon]
    end
  end

  describe "French locale" do
    test "parses 'semaine prochaine soir'" do
      assert {:ok, result} = DateParser.parse("semaine prochaine soir", :fr, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end

    test "parses 'demain matin'" do
      assert {:ok, result} = DateParser.parse("demain matin", :fr, @today)
      assert result.date_range == {~D[2026-04-03], ~D[2026-04-03]}
      assert result.patterns == [:morning]
    end
  end

  describe "German locale" do
    test "parses 'nächste Woche Abend'" do
      assert {:ok, result} = DateParser.parse("nächste Woche Abend", :de, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end

    test "parses 'morgen'" do
      assert {:ok, result} = DateParser.parse("morgen", :de, @today)
      assert result.date_range == {~D[2026-04-03], ~D[2026-04-03]}
    end
  end

  describe "Spanish locale" do
    test "parses 'próxima semana noche'" do
      assert {:ok, result} = DateParser.parse("próxima semana noche", :es, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end

    test "parses 'mañana'" do
      assert {:ok, result} = DateParser.parse("mañana", :es, @today)
      assert result.date_range == {~D[2026-04-03], ~D[2026-04-03]}
    end
  end

  describe "edge cases" do
    test "this week on a Sunday returns just Sunday" do
      sunday = ~D[2026-04-05]
      assert {:ok, result} = DateParser.parse("this week", :en, sunday)
      assert result.date_range == {~D[2026-04-05], ~D[2026-04-05]}
    end

    test "this weekend on a Saturday returns Saturday-Sunday" do
      saturday = ~D[2026-04-04]
      assert {:ok, result} = DateParser.parse("this weekend", :en, saturday)
      assert result.date_range == {~D[2026-04-04], ~D[2026-04-05]}
    end

    test "this weekend on a Sunday returns just Sunday" do
      sunday = ~D[2026-04-05]
      assert {:ok, result} = DateParser.parse("this weekend", :en, sunday)
      assert result.date_range == {~D[2026-04-05], ~D[2026-04-05]}
    end

    test "extra whitespace is handled" do
      assert {:ok, result} = DateParser.parse("  next  week   evening  ", :en, @today)
      assert result.date_range == {~D[2026-04-06], ~D[2026-04-12]}
      assert result.patterns == [:evening]
    end

    test "fully unrecognized input falls back to defaults" do
      assert {:ok, result} = DateParser.parse("xyz abc", :en, @today)
      assert result.date_range == {~D[2026-04-02], ~D[2026-04-05]}
      assert result.patterns == [:morning, :afternoon, :evening]
      assert "xyz" in result.unrecognized
      assert "abc" in result.unrecognized
    end
  end
end

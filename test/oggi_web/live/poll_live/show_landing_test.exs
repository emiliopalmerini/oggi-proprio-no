defmodule OggiWeb.PollLive.ShowLandingTest do
  use OggiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oggi.Polls

  @poll_attrs %{
    title: "Pizza night",
    meeting_duration: 60,
    date_range_start: ~D[2026-04-06],
    date_range_end: ~D[2026-04-06],
    organizer_name: "Alice",
    patterns: [%{kind: :evening, days_of_week: []}]
  }

  defp create_poll(_context) do
    {:ok, poll} = Polls.create_poll(@poll_attrs)
    poll = Polls.get_poll!(poll.id)
    %{poll: poll}
  end

  describe "participant landing page (not joined, poll open)" do
    setup [:create_poll]

    test "shows poll info and join form", %{conn: conn, poll: poll} do
      {:ok, _view, html} = live(conn, "/p/#{poll.participant_token}")

      assert html =~ "Pizza night"
      assert html =~ "Alice"
      assert html =~ "60"
      assert html =~ "06/04/2026"
      assert html =~ "join-form"
    end

    test "does not show the calendar grid", %{conn: conn, poll: poll} do
      {:ok, _view, html} = live(conn, "/p/#{poll.participant_token}")

      refute html =~ "slot-"
      refute html =~ "18:00"
    end

    test "shows the calendar after joining", %{conn: conn, poll: poll} do
      {:ok, view, _html} = live(conn, "/p/#{poll.participant_token}")

      html =
        view
        |> form("#join-form", participant: %{name: "Bob"})
        |> render_submit()

      assert html =~ "slot-"
      assert html =~ "18:00"
    end
  end

  describe "admin always sees the calendar" do
    setup [:create_poll]

    test "admin sees calendar grid immediately", %{conn: conn, poll: poll} do
      {:ok, _view, html} = live(conn, "/p/#{poll.admin_token}")

      assert html =~ "slot-"
      assert html =~ "18:00"
    end
  end

  describe "visitor on closed/resolved poll" do
    setup [:create_poll]

    test "resolved poll shows result banner, no join form", %{conn: conn, poll: poll} do
      {:ok, _poll} = Polls.close_poll(poll.id)

      {:ok, _view, html} = live(conn, "/p/#{poll.participant_token}")

      assert html =~ "hero-check-circle-solid" or html =~ "hero-x-circle-solid"
      refute html =~ "join-form"
    end
  end
end

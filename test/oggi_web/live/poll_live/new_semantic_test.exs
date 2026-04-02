defmodule OggiWeb.PollLive.NewSemanticTest do
  use OggiWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "semantic date input" do
    test "shows date range and time windows on input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: "next week evening"}})

      # Shows resolved dates
      assert html =~ "Mon"
      assert html =~ "Sun"
      # Shows time window
      assert html =~ "18:00"
    end

    test "creates poll from semantic input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First trigger a validate so the parser runs
      view
      |> element("#poll-form")
      |> render_change(%{
        poll: %{
          title: "Aperitivo",
          organizer_name: "Marco",
          meeting_duration: "60",
          when_input: "next week evening"
        }
      })

      view
      |> form("#poll-form",
        poll: %{
          title: "Aperitivo",
          organizer_name: "Marco",
          meeting_duration: "60",
          when_input: "next week evening"
        }
      )
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/p/.+"
    end

    test "unrecognized tokens are silently ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: "next week brunch"}})

      # Shows the resolved date range, "brunch" is ignored
      preview = view |> element("#slot-preview") |> render()
      assert preview =~ "Mon"
      refute preview =~ "brunch"
    end

    test "defaults work with empty input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: ""}})

      # Should show date preview with defaults
      preview_html = view |> element("#slot-preview") |> render()
      assert preview_html =~ ~r/\w+ \d+ \w+/
    end
  end
end

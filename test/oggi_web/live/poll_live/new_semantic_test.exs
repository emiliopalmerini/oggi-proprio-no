defmodule OggiWeb.PollLive.NewSemanticTest do
  use OggiWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "semantic date input" do
    test "shows parsed chips and date preview on input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: "next week evening"}})

      assert html =~ "next week"
      assert html =~ "evening"
      # Should show date range preview
      assert html =~ "Mon"
      assert html =~ "Sun"
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

    test "only shows recognized tokens, ignores unrecognized", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#poll-form")
      |> render_change(%{poll: %{when_input: "next week brunch"}})

      # Chips area should show "next week" but not "brunch"
      chips_html = view |> element("#parsed-chips") |> render()
      assert chips_html =~ "next week"
      refute chips_html =~ "brunch"
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

defmodule OggiWeb.PollLive.NewSemanticTest do
  use OggiWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "semantic date input" do
    test "shows parsed chips and slot preview on input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: "next week evening"}})

      assert html =~ "next week"
      assert html =~ "evening"
      # Should show a slot count preview
      assert html =~ ~r/\d+ slots?/
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

    test "shows guidance for unrecognized tokens", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: "next week brunch"}})

      assert html =~ "brunch"
      # Should still show parsed parts
      assert html =~ "next week"
    end

    test "defaults work with empty input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("#poll-form")
        |> render_change(%{poll: %{when_input: ""}})

      # Should show slot preview with defaults
      assert html =~ ~r/\d+ slots?/
    end
  end
end

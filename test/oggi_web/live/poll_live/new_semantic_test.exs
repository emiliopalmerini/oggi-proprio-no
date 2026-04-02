defmodule OggiWeb.PollLive.NewChipsTest do
  use OggiWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "chip-based poll creation" do
    test "shows date range when selecting a when-chip", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "This weekend") |> render_click()

      preview = view |> element("#slot-preview") |> render()
      assert preview =~ "Sat"
      assert preview =~ "Sun"
    end

    test "toggles time pattern chips", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      # Evening is selected by default
      assert html =~ "btn-primary"

      # Toggle morning on
      view |> element("button", "Morning") |> render_click()
      html = render(view)
      assert html =~ "8:00"
      assert html =~ "18:00"
    end

    test "creates poll from chip selections", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select when
      view |> element("[phx-value-value=next_week]") |> render_click()

      # Select time
      view |> element("button", "Morning") |> render_click()

      # Fill form and submit
      view
      |> form("#poll-form",
        poll: %{
          title: "Aperitivo",
          organizer_name: "Marco",
          meeting_duration: "60"
        }
      )
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/p/.+"
    end

    test "default is next week evening", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Next week chip should be active
      assert html =~ "18:00"
      assert html =~ "Mon"
    end
  end
end

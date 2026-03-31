defmodule OggiWeb.PollLiveTest do
  use OggiWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "full scheduling flow" do
    test "organizer creates poll, participant votes, organizer resolves", %{conn: conn} do
      # Step 1: Organizer visits home and creates a poll
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("#poll-form",
        poll: %{
          title: "Team sync",
          meeting_duration: 60,
          date_range_start: "2026-04-06",
          date_range_end: "2026-04-06",
          organizer_name: "Alice"
        }
      )
      |> render_submit()

      # Should redirect to the admin view
      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/p/.+"

      # Step 2: Organizer sees their poll with generated slots
      {:ok, admin_view, admin_html} = live(conn, path)
      assert admin_html =~ "Team sync"
      assert admin_html =~ "08:00"

      # Grab the participant link from the admin view
      participant_link = get_participant_link(admin_html)

      # Step 3: A participant joins via the participant link
      {:ok, participant_view, _html} = live(conn, participant_link)

      participant_view
      |> form("#join-form", participant: %{name: "Bob"})
      |> render_submit()

      # Step 4: Participant marks the 08:00 slot as unavailable
      participant_html = render(participant_view)
      slot_id = get_first_slot_id(participant_html)

      participant_view
      |> element("#slot-#{slot_id}")
      |> render_click()

      # Verify the slot is now marked as unavailable (red background class)
      assert render(participant_view) =~ "bg-error"

      # Step 5: Organizer closes the poll
      admin_view
      |> element("#close-poll")
      |> render_click()

      # The resolved slot should NOT be 08:00 (Bob can't make it)
      resolved_html = render(admin_view)
      assert resolved_html =~ "We have a winner!"
      assert resolved_html =~ "09:00"
    end
  end

  defp get_participant_link(html) do
    # Extract the participant link from the hidden anchor in the admin page
    [_, link] = Regex.run(~r|href="(/p/[^"]+)"[^>]*class="hidden"|, html)
    link
  end

  defp get_first_slot_id(html) do
    [_, id] = Regex.run(~r|id="slot-([^"]+)"|, html)
    id
  end
end

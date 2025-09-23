defmodule IeeeTamuPortalWeb.AdminEventsLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  alias IeeeTamuPortal.Events

  defp event_attrs(attrs) do
    Map.merge(
      %{
        dtstart: DateTime.utc_now() |> DateTime.truncate(:second),
        dtend: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
        summary: "Test Event",
        description: "Event description",
        location: "ZACH 100",
        organizer: "IEEE TAMU"
      },
      attrs
    )
  end

  defp create_event!(attrs \\ %{}) do
    {:ok, e} = Events.create_event(event_attrs(attrs))
    e
  end

  describe "Admin Events page" do
    test "requires admin basic auth", %{conn: conn} do
      conn = get(conn, ~p"/admin/events")
      assert conn.status == 401
    end

    test "renders page with auth and shows header", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      assert html =~ "Events Management"
      assert html =~ "Create New Event"
    end
  end

  describe "Create Event modal" do
    test "opens and closes modal", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      # Click button to open create modal
      lv |> element("button", "Create New Event") |> render_click()
      assert render(lv) =~ "Create New Event"

      # Cancel closes modal
      lv |> element("button", "Cancel") |> render_click()
      refute render(lv) =~ ~r/Create New Event\s*<\/h2>/
    end

    test "creates a new event with valid data", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      # Open modal
      lv |> element("button", "Create New Event") |> render_click()

      params = %{
        "event" => %{
          "summary" => "General Meeting",
          "organizer" => "IEEE TAMU",
          "dtstart" =>
            DateTime.utc_now() |> DateTime.truncate(:second) |> NaiveDateTime.to_string(),
          "dtend" =>
            DateTime.utc_now()
            |> DateTime.add(3600, :second)
            |> DateTime.truncate(:second)
            |> NaiveDateTime.to_string(),
          "location" => "ZACH 100",
          "description" => "Weekly meeting"
        }
      }

      result =
        lv
        |> form("form", params)
        |> render_submit()

      assert result =~ "Event created successfully"
      assert render(lv) =~ "General Meeting"
    end

    test "shows validation errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      # Open modal
      lv |> element("button", "Create New Event") |> render_click()

      params = %{"event" => %{"summary" => ""}}

      result =
        lv
        |> form("form", params)
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "Edit Event modal" do
    test "opens, updates, and closes edit modal", %{conn: conn} do
      e = create_event!(%{summary: "Original"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      # Click Edit for this event
      lv
      |> element(~s(button[phx-value-uid="#{e.uid}"]), "Edit")
      |> render_click()

      # Change summary
      result =
        lv
        |> form("form", %{"event" => %{"summary" => "Updated"}})
        |> render_submit()

      assert result =~ "Event updated successfully"
      assert render(lv) =~ "Updated"
    end

    test "cancel edit closes modal", %{conn: conn} do
      e = create_event!()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      lv
      |> element(~s(button[phx-value-uid="#{e.uid}"]), "Edit")
      |> render_click()

      lv |> element("button", "Cancel") |> render_click()
      refute render(lv) =~ ~r/Edit Event\s*<\/h2>/
    end
  end

  describe "Delete Event" do
    test "deletes an event", %{conn: conn} do
      e = create_event!(%{summary: "To Delete"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/events")

      lv
      |> element(~s(button[phx-value-uid="#{e.uid}"]), "Delete")
      |> render_click()

      assert render(lv) =~ "Event deleted successfully"
      refute render(lv) =~ "To Delete"
    end
  end
end

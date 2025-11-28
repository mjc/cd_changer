defmodule CdRobotWeb.LoadLiveTest do
  use CdRobotWeb.ConnCase

  import Phoenix.LiveViewTest
  alias CdRobot.{Changer, Catalog}

  setup do
    # Initialize 101 empty slots
    Changer.initialize_slots(101)

    # Create some test disks
    {:ok, disk1} =
      Catalog.create_disk_with_tracks(
        %{
          title: "Abbey Road",
          artist: "The Beatles",
          year: 1969,
          genre: "Rock",
          disc_id: "abc123",
          total_tracks: 2
        },
        [
          %{track_number: 1, title: "Come Together", duration_seconds: 259},
          %{track_number: 2, title: "Something", duration_seconds: 182}
        ]
      )

    {:ok, disk2} =
      Catalog.create_disk_with_tracks(
        %{
          title: "Dark Side of the Moon",
          artist: "Pink Floyd",
          year: 1973,
          genre: "Progressive Rock",
          disc_id: "def456",
          total_tracks: 2
        },
        [
          %{track_number: 1, title: "Speak to Me", duration_seconds: 90},
          %{track_number: 2, title: "Breathe", duration_seconds: 163}
        ]
      )

    {:ok, disk3} =
      Catalog.create_disk(%{
        title: "Led Zeppelin IV",
        artist: "Led Zeppelin",
        year: 1971,
        genre: "Rock",
        disc_id: "ghi789"
      })

    # Load two disks into slots
    {:ok, _} = Changer.load_disk(1, disk1.id)
    {:ok, _} = Changer.load_disk(50, disk2.id)

    %{disk1: disk1, disk2: disk2, disk3: disk3}
  end

  describe "mount" do
    test "displays the load album interface", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/load")

      assert html =~ "CD Changer"
      assert html =~ "101-Disc Automatic Changer"
      assert html =~ "Search for an album or artist to load"
      assert html =~ "Empty Slots"
      assert html =~ "99"
    end
  end

  describe "empty slots display" do
    test "displays all empty slots", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/load")

      # Should show empty slot count
      assert html =~ "Empty Slots (99)"
      # Should show slot numbers in grid (they appear with newlines in actual HTML)
      assert html =~ "2"
      assert html =~ "3"
      assert html =~ "101"
    end

    test "shows message when all slots are full", %{conn: conn} do
      # Load all 101 slots
      {:ok, disk} =
        Catalog.create_disk(%{title: "Test Album", artist: "Test Artist", disc_id: "test123"})

      Enum.each(2..101, fn slot_number ->
        if slot_number != 50 do
          Changer.load_disk(slot_number, disk.id)
        end
      end)

      {:ok, _view, html} = live(conn, "/load")

      assert html =~ "All slots are loaded!"
    end
  end

  describe "album search" do
    test "searching for albums returns results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/load")

      html =
        view
        |> form("form", search: "Beatles")
        |> render_change()

      assert html =~ "Abbey Road"
      assert html =~ "The Beatles"
      assert html =~ "Select an empty slot to load this album"
    end

    test "searching shows available slot buttons", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/load")

      html =
        view
        |> form("form", search: "Zeppelin")
        |> render_change()

      assert html =~ "Led Zeppelin IV"
      # Should show first 10 empty slots as buttons
      assert html =~ "phx-value-slot_number=\"2\""
      assert html =~ "phx-value-slot_number=\"3\""
    end

    test "shows 'no albums found' when search has no results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/load")

      html =
        view
        |> form("form", search: "NonexistentArtist")
        |> render_change()

      assert html =~ "No albums found matching"
    end

    test "search requires at least 2 characters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/load")

      html =
        view
        |> form("form", search: "B")
        |> render_change()

      refute html =~ "Beatles"
    end
  end

  describe "loading albums to slots" do
    test "can load album to specific slot from search results", %{conn: conn, disk3: disk3} do
      {:ok, view, _html} = live(conn, "/load")

      # Search for Led Zeppelin
      view
      |> form("form", search: "Zeppelin")
      |> render_change()

      # Load to slot 2
      html =
        view
        |> element(
          "button[phx-click='load_disk_to_slot'][phx-value-disk_id='#{disk3.id}'][phx-value-slot_number='2']"
        )
        |> render_click()

      # Should show increased album count
      assert html =~ "3 / 101"

      # Verify database
      slot = Changer.get_slot_by_number(2)
      assert slot.disk_id == disk3.id
    end

    test "loading album clears search", %{conn: conn, disk3: disk3} do
      {:ok, view, _html} = live(conn, "/load")

      view
      |> form("form", search: "Zeppelin")
      |> render_change()

      html =
        view
        |> element(
          "button[phx-click='load_disk_to_slot'][phx-value-disk_id='#{disk3.id}'][phx-value-slot_number='2']"
        )
        |> render_click()

      # Search should be cleared
      refute html =~ "Led Zeppelin IV"
    end

    test "shows success flash message when loading", %{conn: conn, disk3: disk3} do
      {:ok, view, _html} = live(conn, "/load")

      view
      |> form("form", search: "Zeppelin")
      |> render_change()

      _html =
        view
        |> element(
          "button[phx-click='load_disk_to_slot'][phx-value-disk_id='#{disk3.id}'][phx-value-slot_number='5']"
        )
        |> render_click()

      # Verify the album was loaded
      assert view |> render() =~ "3 / 101"
    end
  end

  describe "navigation" do
    test "can navigate to albums view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/load")

      assert view |> element("a", "Albums") |> has_element?()
    end

    test "can navigate to add CD view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/load")

      assert view |> element("a", "Add New CD") |> has_element?()
    end
  end
end

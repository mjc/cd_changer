defmodule CdRobotWeb.AlbumsLiveTest do
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
    test "displays the CD changer interface", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "CD Changer"
      assert html =~ "101-Disc Automatic Changer"
      assert html =~ "Loaded Albums"
      assert html =~ "2 / 101"
    end
  end

  describe "albums view" do
    test "displays all loaded albums", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Abbey Road"
      assert html =~ "The Beatles"
      assert html =~ "Dark Side of the Moon"
      assert html =~ "Pink Floyd"
      assert html =~ "Slot 1"
      assert html =~ "Slot 50"
    end

    test "shows album cover images when available", %{conn: conn, disk1: disk1} do
      # Update disk with cover art
      {:ok, _} = Catalog.update_disk(disk1, %{cover_art_url: "https://example.com/cover.jpg"})

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "https://example.com/cover.jpg"
    end

    test "shows placeholder icon when no cover art", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "hero-musical-note"
    end

    test "shows message when no albums are loaded", %{conn: conn} do
      # Unload all disks
      Changer.unload_disk(1)
      Changer.unload_disk(50)

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "No albums loaded"
    end

    test "clicking an album opens detail modal", %{conn: conn, disk1: disk1} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("button[phx-click='select_disk'][phx-value-disk_id='#{disk1.id}']")
        |> render_click()

      assert html =~ "Abbey Road"
      assert html =~ "The Beatles"
      assert html =~ "1969"
      assert html =~ "Rock"
      assert html =~ "Slot 1"
      assert html =~ "Tracks"
      assert html =~ "Come Together"
      assert html =~ "Something"
      assert html =~ "4:19"
      assert html =~ "3:02"
      assert html =~ "Unload Album"
    end

    test "can unload album from detail modal", %{conn: conn, disk1: disk1} do
      {:ok, view, _html} = live(conn, "/")

      # Open modal
      view
      |> element("button[phx-click='select_disk'][phx-value-disk_id='#{disk1.id}']")
      |> render_click()

      # Unload disk
      html =
        view
        |> element("button[phx-click='unload_disk'][phx-value-slot_number='1']")
        |> render_click()

      # Should show success message and Abbey Road should be gone
      assert html =~ "1 / 101"
      refute html =~ "Abbey Road"

      # Verify database
      slot = Changer.get_slot_by_number(1)
      assert is_nil(slot.disk_id)
    end

    test "closing modal returns to albums view", %{conn: conn, disk1: disk1} do
      {:ok, view, _html} = live(conn, "/")

      # Open modal
      view
      |> element("button[phx-click='select_disk'][phx-value-disk_id='#{disk1.id}']")
      |> render_click()

      # Close modal
      html =
        view
        |> element("button[phx-click='close_modal']")
        |> render_click()

      refute html =~ "Unload Album"
    end
  end

  describe "format_duration helper" do
    test "formats duration correctly", %{conn: conn, disk1: disk1} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("button[phx-click='select_disk'][phx-value-disk_id='#{disk1.id}']")
        |> render_click()

      # 259 seconds = 4:19
      assert html =~ "4:19"
      # 182 seconds = 3:02
      assert html =~ "3:02"
    end
  end
end

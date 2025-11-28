defmodule CdRobot.Catalog.DiskTest do
  use CdRobot.DataCase

  alias CdRobot.Catalog.Disk

  describe "disk changeset" do
    test "valid changeset with all fields" do
      attrs = %{
        title: "Abbey Road",
        artist: "The Beatles",
        genre: "Rock",
        year: 1969,
        disc_id: "810b9e0c",
        total_tracks: 17,
        duration_seconds: 2830,
        cover_art_url: "https://example.com/abbey-road.jpg"
      }

      changeset = Disk.changeset(%Disk{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with only disc_id" do
      attrs = %{disc_id: "810b9e0c"}
      changeset = Disk.changeset(%Disk{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without disc_id" do
      attrs = %{
        title: "Abbey Road",
        artist: "The Beatles"
      }

      changeset = Disk.changeset(%Disk{}, attrs)
      refute changeset.valid?
      assert %{disc_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "unique constraint on disc_id" do
      attrs = %{disc_id: "810b9e0c", title: "Test Album", artist: "Test Artist"}
      {:ok, _disk} = Repo.insert(Disk.changeset(%Disk{}, attrs))

      {:error, changeset} =
        Repo.insert(Disk.changeset(%Disk{}, attrs))

      assert %{disc_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "accepts nil for optional fields" do
      attrs = %{
        disc_id: "810b9e0c",
        title: nil,
        artist: nil,
        genre: nil,
        year: nil,
        total_tracks: nil,
        duration_seconds: nil,
        cover_art_url: nil
      }

      changeset = Disk.changeset(%Disk{}, attrs)
      assert changeset.valid?
    end
  end

  describe "disk associations" do
    test "has_one slot association" do
      assert %Ecto.Association.Has{} = Disk.__schema__(:association, :slot)
    end

    test "has_many tracks association" do
      assert %Ecto.Association.Has{} = Disk.__schema__(:association, :tracks)
    end
  end
end

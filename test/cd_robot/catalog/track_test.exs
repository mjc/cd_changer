defmodule CdRobot.Catalog.TrackTest do
  use CdRobot.DataCase

  alias CdRobot.Catalog.{Disk, Track}

  setup do
    {:ok, disk} =
      Repo.insert(
        Disk.changeset(%Disk{}, %{
          disc_id: "810b9e0c",
          title: "Abbey Road",
          artist: "The Beatles"
        })
      )

    %{disk: disk}
  end

  describe "track changeset" do
    test "valid changeset with all fields", %{disk: disk} do
      attrs = %{
        disk_id: disk.id,
        track_number: 1,
        title: "Come Together",
        artist: "The Beatles",
        duration_seconds: 259
      }

      changeset = Track.changeset(%Track{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with only required fields", %{disk: disk} do
      attrs = %{
        disk_id: disk.id,
        track_number: 1
      }

      changeset = Track.changeset(%Track{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without track_number", %{disk: disk} do
      attrs = %{
        disk_id: disk.id,
        title: "Come Together"
      }

      changeset = Track.changeset(%Track{}, attrs)
      refute changeset.valid?
      assert %{track_number: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without disk_id" do
      attrs = %{
        track_number: 1,
        title: "Come Together"
      }

      changeset = Track.changeset(%Track{}, attrs)
      refute changeset.valid?
      assert %{disk_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "unique constraint on disk_id and track_number", %{disk: disk} do
      attrs = %{
        disk_id: disk.id,
        track_number: 1,
        title: "Come Together"
      }

      {:ok, _track} = Repo.insert(Track.changeset(%Track{}, attrs))

      {:error, changeset} =
        Repo.insert(Track.changeset(%Track{}, attrs))

      assert %{disk_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same track_number for different disks", %{disk: disk1} do
      {:ok, disk2} =
        Repo.insert(
          Disk.changeset(%Disk{}, %{
            disc_id: "abc123",
            title: "Another Album"
          })
        )

      attrs1 = %{disk_id: disk1.id, track_number: 1, title: "Track 1"}
      attrs2 = %{disk_id: disk2.id, track_number: 1, title: "Track 1"}

      {:ok, _track1} = Repo.insert(Track.changeset(%Track{}, attrs1))
      {:ok, _track2} = Repo.insert(Track.changeset(%Track{}, attrs2))

      assert Repo.aggregate(Track, :count) == 2
    end
  end

  describe "track associations" do
    test "belongs_to disk association" do
      assert %Ecto.Association.BelongsTo{} = Track.__schema__(:association, :disk)
    end
  end

  describe "cascade delete" do
    test "tracks are deleted when disk is deleted", %{disk: disk} do
      {:ok, _track} =
        Repo.insert(
          Track.changeset(%Track{}, %{
            disk_id: disk.id,
            track_number: 1,
            title: "Track 1"
          })
        )

      {:ok, _track} =
        Repo.insert(
          Track.changeset(%Track{}, %{
            disk_id: disk.id,
            track_number: 2,
            title: "Track 2"
          })
        )

      assert Repo.aggregate(Track, :count) == 2

      Repo.delete(disk)

      assert Repo.aggregate(Track, :count) == 0
    end
  end
end

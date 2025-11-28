# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CdRobot.Repo.insert!(%CdRobot.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query
alias CdRobot.Repo
alias CdRobot.Catalog.Disk
alias CdRobot.Changer

# Initialize 101 slots
Changer.initialize_slots(101)

# Sample disks for testing
sample_disks = [
  %{
    disc_id: "810b9e0c",
    title: "Abbey Road",
    artist: "The Beatles",
    genre: "Rock",
    year: 1969,
    total_tracks: 17,
    duration_seconds: 2830
  },
  %{
    disc_id: "a1b2c3d4",
    title: "Dark Side of the Moon",
    artist: "Pink Floyd",
    genre: "Progressive Rock",
    year: 1973,
    total_tracks: 10,
    duration_seconds: 2583
  },
  %{
    disc_id: "e5f6g7h8",
    title: "Thriller",
    artist: "Michael Jackson",
    genre: "Pop",
    year: 1982,
    total_tracks: 9,
    duration_seconds: 2523
  },
  %{
    disc_id: "i9j0k1l2",
    title: "The Wall",
    artist: "Pink Floyd",
    genre: "Progressive Rock",
    year: 1979,
    total_tracks: 26,
    duration_seconds: 4860
  },
  %{
    disc_id: "m3n4o5p6",
    title: "Led Zeppelin IV",
    artist: "Led Zeppelin",
    genre: "Rock",
    year: 1971,
    total_tracks: 8,
    duration_seconds: 2552
  }
]

for disk_attrs <- sample_disks do
  case Repo.get_by(Disk, disc_id: disk_attrs.disc_id) do
    nil ->
      %Disk{}
      |> Disk.changeset(disk_attrs)
      |> Repo.insert!()

    _disk ->
      :ok
  end
end

defmodule CdRobot.Catalog.Disk do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "disks" do
    field :title, :string
    field :artist, :string
    field :genre, :string
    field :year, :integer
    field :disc_id, :string
    field :total_tracks, :integer
    field :duration_seconds, :integer
    field :cover_art_url, :string

    has_one :slot, CdRobot.Changer.Slot
    has_many :tracks, CdRobot.Catalog.Track

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(disk, attrs) do
    disk
    |> cast(attrs, [
      :title,
      :artist,
      :genre,
      :year,
      :disc_id,
      :total_tracks,
      :duration_seconds,
      :cover_art_url
    ])
    |> validate_required([:disc_id])
    |> unique_constraint(:disc_id)
  end
end

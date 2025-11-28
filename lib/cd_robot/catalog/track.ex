defmodule CdRobot.Catalog.Track do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tracks" do
    field :track_number, :integer
    field :title, :string
    field :artist, :string
    field :duration_seconds, :integer
    belongs_to :disk, CdRobot.Catalog.Disk, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(track, attrs) do
    track
    |> cast(attrs, [:track_number, :title, :artist, :duration_seconds, :disk_id])
    |> validate_required([:track_number, :disk_id])
    |> foreign_key_constraint(:disk_id, name: "tracks_disk_id_fkey")
    |> unique_constraint([:disk_id, :track_number])
  end
end

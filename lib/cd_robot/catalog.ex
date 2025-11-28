defmodule CdRobot.Catalog do
  @moduledoc """
  The Catalog context for managing disks and tracks.
  """

  import Ecto.Query, warn: false
  alias CdRobot.Repo
  alias CdRobot.Catalog.{Disk, Track}

  @doc """
  Returns the list of disks.
  """
  def list_disks do
    Disk
    |> order_by([d], asc: d.artist, asc: d.title)
    |> preload(:tracks)
    |> Repo.all()
  end

  @doc """
  Searches disks by title or artist.
  """
  def search_disks(query) when is_binary(query) do
    search_term = "%#{query}%"

    Disk
    |> where(
      [d],
      like(fragment("LOWER(?)", d.title), fragment("LOWER(?)", ^search_term)) or
        like(fragment("LOWER(?)", d.artist), fragment("LOWER(?)", ^search_term))
    )
    |> order_by([d], asc: d.artist, asc: d.title)
    |> limit(20)
    |> preload(:tracks)
    |> Repo.all()
  end

  @doc """
  Gets a single disk.
  """
  def get_disk!(id), do: Repo.get!(Disk, id) |> Repo.preload(:tracks)

  @doc """
  Creates a disk.
  """
  def create_disk(attrs \\ %{}) do
    %Disk{}
    |> Disk.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a disk with associated tracks in a transaction.
  """
  def create_disk_with_tracks(disk_attrs, tracks_attrs) when is_list(tracks_attrs) do
    Repo.transaction(fn ->
      # Check if disk already exists by disc_id
      existing_disk =
        case disk_attrs do
          %{disc_id: disc_id} when not is_nil(disc_id) ->
            Repo.get_by(Disk, disc_id: disc_id)

          _ ->
            nil
        end

      disk =
        case existing_disk do
          nil ->
            # Create new disk
            case create_disk(disk_attrs) do
              {:ok, disk} -> disk
              {:error, changeset} -> Repo.rollback(changeset)
            end

          existing ->
            # Update existing disk
            case update_disk(existing, disk_attrs) do
              {:ok, disk} -> disk
              {:error, changeset} -> Repo.rollback(changeset)
            end
        end

      # Delete old tracks if updating
      if existing_disk do
        Repo.delete_all(from t in Track, where: t.disk_id == ^disk.id)
      end

      # Insert new tracks
      case insert_tracks(disk, tracks_attrs) do
        {:ok, _tracks} -> disk |> Repo.preload(:tracks)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_tracks(disk, tracks_attrs) do
    tracks =
      Enum.map(tracks_attrs, fn track_attrs ->
        track_attrs
        |> Map.put(:disk_id, disk.id)
        |> then(&Track.changeset(%Track{}, &1))
      end)

    case Enum.find(tracks, &(!&1.valid?)) do
      nil ->
        inserted_tracks = Enum.map(tracks, &Repo.insert!/1)
        {:ok, inserted_tracks}

      invalid_changeset ->
        {:error, invalid_changeset}
    end
  end

  @doc """
  Updates a disk.
  """
  def update_disk(%Disk{} = disk, attrs) do
    disk
    |> Disk.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a disk.
  """
  def delete_disk(%Disk{} = disk) do
    Repo.delete(disk)
  end

  @doc """
  Creates a track.
  """
  def create_track(attrs \\ %{}) do
    %Track{}
    |> Track.changeset(attrs)
    |> Repo.insert()
  end
end

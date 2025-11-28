defmodule CdRobot.MusicBrainz do
  @moduledoc """
  MusicBrainz API client for CD metadata lookup.
  """

  require Logger

  @doc """
  Search for an album by artist and title.
  Returns a list of matching albums with their metadata.
  If album is empty, returns all albums by the artist.
  """
  def search_album(artist, album) do
    query =
      if album == "" do
        "artist:#{artist}"
      else
        "artist:#{artist} AND release:#{album}"
      end

    case SonEx.MusicBrainz.search_releases(query, limit: 25) do
      {:ok, %{"releases" => releases}} when is_list(releases) and length(releases) > 0 ->
        results =
          releases
          |> Enum.map(&parse_release/1)
          |> Enum.uniq_by(fn release ->
            # Deduplicate by artist + album name (case-insensitive)
            {String.downcase(release.artist), String.downcase(release.album)}
          end)
          |> Enum.take(25)

        {:ok, results}

      {:ok, %{"releases" => []}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("MusicBrainz API error: #{inspect(reason)}")
        {:error, :api_error}
    end
  end

  defp parse_release(release) do
    artist =
      case release do
        %{"artist-credit" => [%{"name" => name} | _]} -> name
        _ -> "Unknown Artist"
      end

    album = Map.get(release, "title", "Unknown Album")
    mbid = Map.get(release, "id")
    date = Map.get(release, "date")
    year = if date, do: String.slice(date, 0..3), else: nil

    %{
      category: "data",
      disc_id: mbid,
      artist: artist,
      album: album,
      year: year
    }
  end

  @doc """
  Get cover art URL from Cover Art Archive.
  """
  def get_cover_art(mbid) do
    url = "https://coverartarchive.org/release/#{mbid}/front-500"

    case Req.head(url, redirect: false) do
      {:ok, %{status: status}} when status in 200..399 ->
        {:ok, url}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Get detailed information for a specific disc ID (MusicBrainz ID).
  """
  def get_disc_info(_category, mbid) do
    case SonEx.MusicBrainz.lookup_release(mbid, inc: ["recordings", "artist-credits"]) do
      {:ok, release} ->
        parse_disc_info(release, mbid)

      {:error, reason} ->
        Logger.error("MusicBrainz API error: #{inspect(reason)}")
        {:error, :api_error}
    end
  end

  defp parse_disc_info(release, mbid) do
    artist =
      case release do
        %{"artist-credit" => [%{"name" => name} | _]} -> name
        _ -> "Unknown Artist"
      end

    album = Map.get(release, "title", "Unknown Album")
    date = Map.get(release, "date")

    year =
      if date do
        case Integer.parse(String.slice(date, 0..3)) do
          {y, _} -> y
          _ -> nil
        end
      end

    tracks =
      case release do
        %{"media" => [%{"tracks" => track_list} | _]} ->
          Enum.map(track_list, fn track ->
            position =
              case Map.get(track, "position") do
                pos when is_integer(pos) ->
                  pos

                pos when is_binary(pos) ->
                  case Integer.parse(pos) do
                    {num, _} -> num
                    _ -> 1
                  end

                _ ->
                  1
              end

            %{
              track_number: position,
              title: Map.get(track, "title", "Unknown Track")
            }
          end)

        _ ->
          []
      end

    # Fetch cover art URL from Cover Art Archive
    cover_art_url =
      case get_cover_art(mbid) do
        {:ok, url} -> url
        _ -> nil
      end

    info = %{
      artist: artist,
      album: album,
      year: year,
      tracks: tracks,
      cover_art_url: cover_art_url
    }

    {:ok, info}
  end

  @doc """
  Generate a fallback disc ID from artist and album name.
  Used when MusicBrainz doesn't have the album.
  """
  def generate_disc_id(artist, album) do
    :crypto.hash(:md5, "#{artist}#{album}")
    |> Base.encode16(case: :lower)
    |> String.slice(0..7)
  end
end

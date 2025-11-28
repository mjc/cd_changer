defmodule CdRobot.MusicBrainz do
  @moduledoc """
  MusicBrainz API client for CD metadata lookup with rate limiting.
  """
  use GenServer
  require Logger

  @rate_limit_ms 1000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Asynchronously looks up an album on MusicBrainz and sends the result back to the caller.
  """
  def lookup_album(caller_pid, artist, album) do
    GenServer.cast(__MODULE__, {:lookup_album, caller_pid, artist, album})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{last_request_at: nil}}
  end

  @impl true
  def handle_cast({:lookup_album, caller_pid, artist, album}, state) do
    # Rate limit: wait if we made a request too recently
    state = maybe_wait_for_rate_limit(state)

    Logger.debug("MusicBrainz performing lookup for: #{artist} - #{album}")

    # Perform the lookup
    result = search_album(artist, album)

    Logger.debug("MusicBrainz lookup result: #{inspect(result)}")

    # Send result back to caller
    send(caller_pid, {:musicbrainz_result, result, artist, album})

    {:noreply, %{state | last_request_at: System.monotonic_time(:millisecond)}}
  end

  defp maybe_wait_for_rate_limit(%{last_request_at: nil} = state), do: state

  defp maybe_wait_for_rate_limit(%{last_request_at: last_request_at} = state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - last_request_at

    if elapsed < @rate_limit_ms do
      wait_time = @rate_limit_ms - elapsed
      Logger.debug("Rate limiting MusicBrainz request, waiting #{wait_time}ms")
      Process.sleep(wait_time)
    end

    state
  end

  # MusicBrainz API Functions

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

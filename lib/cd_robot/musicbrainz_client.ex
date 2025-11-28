defmodule CdRobot.MusicBrainzClient do
  @moduledoc """
  GenServer that handles MusicBrainz API requests with rate limiting to avoid hammering the service.
  """
  use GenServer
  require Logger

  alias CdRobot.MusicBrainz

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

    Logger.debug("MusicBrainzClient performing lookup for: #{artist} - #{album}")

    # Perform the lookup
    result = MusicBrainz.search_album(artist, album)

    Logger.debug("MusicBrainzClient lookup result: #{inspect(result)}")

    # Send result back to caller
    send(caller_pid, {:musicbrainz_result, result, artist, album})

    {:noreply, %{state | last_request_at: System.monotonic_time(:millisecond)}}
  end

  # Private Functions

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
end

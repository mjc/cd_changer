defmodule CdRobotWeb.AddLive do
  use CdRobotWeb, :live_view
  alias CdRobot.{Changer, Catalog, MusicBrainz}

  @impl true
  def mount(_params, _session, socket) do
    slots = Changer.list_slots()

    {:ok,
     socket
     |> assign(:slots, slots)
     |> assign(:musicbrainz_results, [])
     |> assign(:musicbrainz_query, "")
     |> assign(:gnudb_loading, false)
     |> assign(:debounce_timer, nil)
     |> assign(:page_title, "Add New CD")}
  end

  @impl true
  def handle_event("search_musicbrainz", %{"query" => query}, socket) do
    query = String.trim(query)

    # Cancel existing timer if any
    if socket.assigns.debounce_timer do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end

    socket = assign(socket, :musicbrainz_query, query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:musicbrainz_results, [])
       |> assign(:gnudb_loading, false)
       |> assign(:debounce_timer, nil)}
    else
      # Set a timer to trigger search after 500ms of no typing
      timer = Process.send_after(self(), {:do_musicbrainz_search, query}, 500)
      {:noreply, assign(socket, :debounce_timer, timer)}
    end
  end

  def handle_event("select_musicbrainz_result", %{"disc_id" => disc_id}, socket) do
    result = Enum.find(socket.assigns.musicbrainz_results, &(&1.disc_id == disc_id))

    socket =
      if result do
        case MusicBrainz.get_disc_info(result.category, result.disc_id) do
          {:ok, disc_info} ->
            create_disk_from_musicbrainz(socket, disc_info, result.disc_id)

          {:error, _} ->
            # Fallback to basic disk using result data
            create_basic_disk(socket, result.artist, result.album)
        end
      else
        socket
        |> put_flash(:error, "Invalid selection")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:do_musicbrainz_search, query}, socket) do
    require Logger
    Logger.debug("Triggering MusicBrainz search for: #{inspect(query)}")

    # Only search if the query hasn't changed
    if query == socket.assigns.musicbrainz_query do
      # Parse query - assume "artist - album" format, or just artist
      {artist, album} = parse_search_query(query)

      Logger.debug("Parsed artist: #{artist}, album: #{album}")

      MusicBrainz.lookup_album(self(), artist, album)
      {:noreply, assign(socket, :gnudb_loading, true)}
    else
      Logger.debug("Query changed, skipping search")
      {:noreply, socket}
    end
  end

  def handle_info({:musicbrainz_result, result, _artist, _album}, socket) do
    require Logger
    Logger.debug("Received MusicBrainz result: #{inspect(result)}")

    socket =
      case result do
        {:ok, [_ | _] = results} ->
          socket
          |> assign(:musicbrainz_results, results)
          |> assign(:gnudb_loading, false)

        {:error, :not_found} ->
          socket
          |> assign(:musicbrainz_results, [])
          |> assign(:gnudb_loading, false)

        {:error, _} ->
          socket
          |> assign(:musicbrainz_results, [])
          |> assign(:gnudb_loading, false)
      end

    {:noreply, socket}
  end

  defp parse_search_query(query) do
    case String.split(query, " - ", parts: 2) do
      [artist, album] -> {String.trim(artist), String.trim(album)}
      [artist] -> {String.trim(artist), ""}
    end
  end

  defp create_disk_from_musicbrainz(socket, disc_info, disc_id) do
    disk_attrs = %{
      title: disc_info[:album] || disc_info[:title],
      artist: disc_info[:artist],
      disc_id: disc_id,
      year: disc_info[:year],
      genre: disc_info[:genre],
      total_tracks: length(disc_info[:tracks] || []),
      cover_art_url: disc_info[:cover_art_url]
    }

    tracks_attrs = disc_info[:tracks] || []

    case Catalog.create_disk_with_tracks(disk_attrs, tracks_attrs) do
      {:ok, _disk} ->
        socket
        |> assign(:musicbrainz_results, [])
        |> assign(:musicbrainz_query, "")
        |> put_flash(
          :info,
          "Album '#{disk_attrs.title}' by #{disk_attrs.artist} added. Select a slot to load it."
        )
        |> push_navigate(to: ~p"/load")

      {:error, changeset} ->
        error_message =
          cond do
            changeset.errors[:disc_id] ->
              "This album is already in your catalog"

            changeset.errors[:title] ->
              "Album title is required"

            changeset.errors[:artist] ->
              "Artist name is required"

            true ->
              "Failed to add album. Please try again."
          end

        socket
        |> assign(:musicbrainz_results, [])
        |> put_flash(:error, error_message)
    end
  end

  defp create_basic_disk(socket, artist, album) do
    disc_id = MusicBrainz.generate_disc_id(artist, album)

    case Catalog.create_disk(%{
           title: album,
           artist: artist,
           disc_id: disc_id
         }) do
      {:ok, _disk} ->
        socket
        |> assign(:musicbrainz_results, [])
        |> assign(:musicbrainz_query, "")
        |> put_flash(
          :info,
          "Album '#{album}' by #{artist} added. Select a slot to load it."
        )
        |> push_navigate(to: ~p"/load")

      {:error, changeset} ->
        error_message =
          cond do
            changeset.errors[:disc_id] ->
              "This album is already in your catalog"

            changeset.errors[:title] ->
              "Album title is required"

            changeset.errors[:artist] ->
              "Artist name is required"

            true ->
              "Failed to add album. Please try again."
          end

        socket
        |> assign(:musicbrainz_results, [])
        |> put_flash(:error, error_message)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 p-4">
      <div class="max-w-7xl mx-auto">
        <.nav_header slots={@slots} live_action={@live_action} />

        <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
          <div class="max-w-2xl mx-auto">
            <div class="text-center mb-8">
              <div class="inline-flex items-center justify-center w-16 h-16 bg-blue-600/20 rounded-full mb-4">
                <.icon name="hero-plus-circle" class="w-8 h-8 text-blue-400" />
              </div>
              <h2 class="text-2xl font-bold text-white mb-2">Add New CD to Catalog</h2>
              <p class="text-slate-400">
                Enter the artist and album name to look up metadata from MusicBrainz
              </p>
            </div>

            <div class="space-y-6">
              <div>
                <label class="block text-sm font-semibold text-slate-300 mb-2">
                  Search for Album
                </label>
                <form phx-change="search_musicbrainz">
                  <div class="relative">
                    <input
                      type="text"
                      name="query"
                      value={@musicbrainz_query}
                      placeholder="Search by artist or 'Artist - Album'..."
                      class="w-full px-4 py-3 pr-12 bg-slate-900 border border-slate-600 rounded-lg text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
                      autofocus
                    />
                    <%= if @gnudb_loading do %>
                      <div class="absolute right-4 top-1/2 -translate-y-1/2">
                        <svg
                          class="w-5 h-5 animate-spin text-blue-400"
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                        >
                          <circle
                            class="opacity-25"
                            cx="12"
                            cy="12"
                            r="10"
                            stroke="currentColor"
                            stroke-width="4"
                          >
                          </circle>
                          <path
                            class="opacity-75"
                            fill="currentColor"
                            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                          >
                          </path>
                        </svg>
                      </div>
                    <% end %>
                  </div>
                </form>
                <p class="mt-2 text-xs text-slate-500">
                  Type artist name for all albums, or "Artist - Album" for specific album
                </p>
              </div>
            </div>

            <%= if Enum.any?(@musicbrainz_results) do %>
              <div class="mt-6">
                <h3 class="text-lg font-semibold text-white mb-4">
                  Select the correct album:
                </h3>
                <div class="space-y-3">
                  <%= for result <- @musicbrainz_results do %>
                    <button
                      phx-click="select_musicbrainz_result"
                      phx-value-disc_id={result.disc_id}
                      class="w-full p-4 bg-slate-900/50 hover:bg-slate-700/50 border border-slate-600 hover:border-blue-500 rounded-lg text-left transition-all"
                    >
                      <div class="font-semibold text-white"><%= result.album %></div>
                      <div class="text-sm text-slate-400">by <%= result.artist %></div>
                      <%= if result.year do %>
                        <div class="text-xs text-slate-500 mt-1">Released: <%= result.year %></div>
                      <% end %>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <div class="mt-8 p-4 bg-slate-900/50 rounded-lg border border-slate-700">
              <div class="flex gap-3">
                <.icon name="hero-information-circle" class="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <div class="text-sm text-slate-400">
                  <p class="mb-2">
                    <strong class="text-slate-300">No CD drive detected.</strong>
                    You can manually add CDs by entering the artist and album information.
                  </p>
                  <p>
                    The system will attempt to look up track listings and metadata from the MusicBrainz database.
                    If not found, a basic entry will be created that you can edit later.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp nav_header(assigns) do
    ~H"""
    <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 mb-6 border border-slate-700">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h1 class="text-3xl font-bold text-white mb-1">CD Changer</h1>
          <p class="text-slate-400">101-Disc Automatic Changer</p>
        </div>
        <div class="text-slate-400">
          <div class="text-sm">Loaded Albums</div>
          <div class="text-2xl font-bold text-white">
            <%= Enum.count(@slots, & &1.disk_id) %> / 101
          </div>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-2">
        <.link
          navigate={~p"/"}
          class="px-4 py-3 rounded-lg font-semibold transition-all text-center bg-slate-700 text-slate-300 hover:bg-slate-600"
        >
          <.icon name="hero-musical-note" class="w-5 h-5 inline mr-2" />
          Albums
        </.link>
        <.link
          navigate={~p"/load"}
          class="px-4 py-3 rounded-lg font-semibold transition-all text-center bg-slate-700 text-slate-300 hover:bg-slate-600"
        >
          <.icon name="hero-plus-circle" class="w-5 h-5 inline mr-2" />
          Load Album
        </.link>
        <.link
          patch={~p"/add"}
          class={[
            "px-4 py-3 rounded-lg font-semibold transition-all text-center",
            if(@live_action == :add,
              do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
              else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
            )
          ]}
        >
          <.icon name="hero-plus" class="w-5 h-5 inline mr-2" />
          Add New CD
        </.link>
      </div>
    </div>
    """
  end
end

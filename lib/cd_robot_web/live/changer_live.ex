defmodule CdRobotWeb.ChangerLive do
  use CdRobotWeb, :live_view
  alias CdRobot.{Changer, Catalog, MusicBrainz}

  @impl true
  def mount(_params, _session, socket) do
    slots = Changer.list_slots()

    {:ok,
     socket
     |> assign(:slots, slots)
     |> assign(:view_mode, :albums)
     |> assign(:selected_disk, nil)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:musicbrainz_results, [])
     |> assign(:musicbrainz_query, "")
     |> assign(:gnudb_loading, false)
     |> assign(:debounce_timer, nil)
     |> assign(:page_title, "CD Changer")}
  end

  @impl true
  def handle_event("switch_view", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(:view_mode, String.to_existing_atom(mode))
     |> assign(:musicbrainz_query, "")
     |> assign(:musicbrainz_results, [])}
  end

  def handle_event("select_disk", %{"disk_id" => disk_id}, socket) do
    slot = Enum.find(socket.assigns.slots, &(&1.disk_id == disk_id))

    {:noreply, assign(socket, selected_disk: slot)}
  end

  def handle_event("search_disks", %{"search" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Catalog.search_disks(query)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  def handle_event(
        "load_disk_to_slot",
        %{"disk_id" => disk_id, "slot_number" => slot_number},
        socket
      ) do
    slot_number = String.to_integer(slot_number)

    case Changer.load_disk(slot_number, disk_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:slots, Changer.list_slots())
         |> assign(:search_query, "")
         |> assign(:search_results, [])
         |> put_flash(:info, "Album loaded into slot #{slot_number}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load album")}
    end
  end

  def handle_event("unload_disk", %{"slot_number" => slot_number}, socket) do
    slot_number = String.to_integer(slot_number)

    case Changer.unload_disk(slot_number) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:slots, Changer.list_slots())
         |> assign(:selected_disk, nil)
         |> put_flash(:info, "Album unloaded from slot #{slot_number}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to unload album")}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_disk, nil)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:musicbrainz_results, [])
     |> assign(:musicbrainz_query, "")}
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

  @impl true
  def handle_info({:do_musicbrainz_search, query}, socket) do
    # Only search if the query hasn't changed
    if query == socket.assigns.musicbrainz_query do
      # Parse query - assume "artist - album" format, or just artist
      {artist, album} = parse_search_query(query)

      MusicBrainz.lookup_album(self(), artist, album)
      {:noreply, assign(socket, :gnudb_loading, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:musicbrainz_result, result, _artist, _album}, socket) do
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
        slots = Changer.list_slots()

        socket
        |> assign(:view_mode, :albums)
        |> assign(:slots, slots)
        |> assign(:musicbrainz_results, [])
        |> assign(:musicbrainz_query, "")
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> put_flash(
          :info,
          "Album '#{disk_attrs.title}' by #{disk_attrs.artist} added with #{length(tracks_attrs)} tracks from MusicBrainz"
        )

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
        slots = Changer.list_slots()

        socket
        |> assign(:view_mode, :albums)
        |> assign(:slots, slots)
        |> assign(:musicbrainz_results, [])
        |> assign(:musicbrainz_query, "")
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> put_flash(
          :info,
          "Album '#{album}' by #{artist} added to catalog (MusicBrainz lookup unsuccessful, basic entry created)"
        )

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
        <%!-- Header --%>
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

          <%!-- View Mode Toggle --%>
          <div class="grid grid-cols-3 gap-2">
            <button
              phx-click="switch_view"
              phx-value-mode="albums"
              class={[
                "px-4 py-3 rounded-lg font-semibold transition-all",
                if(@view_mode == :albums,
                  do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
                  else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
                )
              ]}
            >
              <.icon name="hero-musical-note" class="w-5 h-5 inline mr-2" />
              Albums
            </button>
            <button
              phx-click="switch_view"
              phx-value-mode="empty_slots"
              class={[
                "px-4 py-3 rounded-lg font-semibold transition-all",
                if(@view_mode == :empty_slots,
                  do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
                  else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
                )
              ]}
            >
              <.icon name="hero-plus-circle" class="w-5 h-5 inline mr-2" />
              Load Album
            </button>
            <button
              phx-click="switch_view"
              phx-value-mode="new_cd"
              class={[
                "px-4 py-3 rounded-lg font-semibold transition-all",
                if(@view_mode == :new_cd,
                  do: "bg-blue-600 text-white shadow-lg shadow-blue-500/50",
                  else: "bg-slate-700 text-slate-300 hover:bg-slate-600"
                )
              ]}
            >
              <.icon name="hero-plus" class="w-5 h-5 inline mr-2" />
              Add New CD
            </button>
          </div>
        </div>

        <%= cond do %>
          <% @view_mode == :albums -> %>
          <%!-- Albums View --%>
          <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
            <%= if Enum.any?(@slots, & &1.disk_id) do %>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                <%= for slot <- @slots, slot.disk do %>
                  <button
                    phx-click="select_disk"
                    phx-value-disk_id={slot.disk.id}
                    class="bg-slate-900/60 hover:bg-slate-900 rounded-xl p-4 transition-all border border-slate-700 hover:border-blue-500 hover:shadow-lg hover:shadow-blue-500/20 text-left group"
                  >
                    <div class="flex gap-4">
                      <%= if slot.disk.cover_art_url do %>
                        <img
                          src={slot.disk.cover_art_url}
                          alt={slot.disk.title}
                          class="w-20 h-20 object-cover rounded-lg shadow-lg group-hover:shadow-xl transition-shadow"
                        />
                      <% else %>
                        <div class="w-20 h-20 bg-gradient-to-br from-slate-700 to-slate-800 rounded-lg flex items-center justify-center shadow-lg">
                          <.icon name="hero-musical-note" class="w-10 h-10 text-slate-500" />
                        </div>
                      <% end %>
                      <div class="flex-1 min-w-0">
                        <h3 class="font-bold text-white truncate mb-1">
                          <%= slot.disk.title || "Unknown Album" %>
                        </h3>
                        <p class="text-sm text-slate-300 truncate mb-2">
                          <%= slot.disk.artist || "Unknown Artist" %>
                        </p>
                        <div class="flex items-center gap-2 text-xs text-slate-500">
                          <%= if slot.disk.year do %>
                            <span><%= slot.disk.year %></span>
                            <span>•</span>
                          <% end %>
                          <span>Slot <%= slot.slot_number %></span>
                        </div>
                      </div>
                    </div>
                  </button>
                <% end %>
              </div>
            <% else %>
              <div class="text-center py-16 text-slate-500">
                <.icon name="hero-musical-note" class="w-16 h-16 mx-auto mb-4 opacity-50" />
                <p class="text-xl mb-2">No albums loaded</p>
                <p class="text-sm">Switch to "Load Album" to add albums to your changer</p>
              </div>
            <% end %>
          </div>

          <% @view_mode == :empty_slots -> %>
          <%!-- Empty Slots View --%>
          <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
            <%!-- Search Bar --%>
            <form phx-change="search_disks" class="mb-6">
              <div class="relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500"
                />
                <input
                  type="text"
                  name="search"
                  value={@search_query}
                  placeholder="Search for an album or artist to load..."
                  autocomplete="off"
                  class="w-full pl-12 pr-4 py-3 bg-slate-900 border border-slate-600 rounded-lg text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </form>

            <%= if @search_query != "" do %>
              <%!-- Search Results --%>
              <%= if @search_results == [] do %>
                <div class="text-center py-12 text-slate-500">
                  <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto mb-3 opacity-50" />
                  <p>No albums found matching "<%= @search_query %>"</p>
                </div>
              <% else %>
                <div class="mb-8">
                  <h3 class="text-sm font-semibold text-slate-400 mb-3 uppercase tracking-wide">
                    Search Results
                  </h3>
                  <div class="grid grid-cols-1 gap-3">
                    <%= for disk <- @search_results do %>
                      <div class="bg-slate-900/60 rounded-lg p-4 border border-slate-700">
                        <div class="flex items-center gap-4 mb-3">
                          <%= if disk.cover_art_url do %>
                            <img
                              src={disk.cover_art_url}
                              alt={disk.title}
                              class="w-16 h-16 object-cover rounded shadow-lg"
                            />
                          <% else %>
                            <div class="w-16 h-16 bg-slate-800 rounded flex items-center justify-center">
                              <.icon name="hero-musical-note" class="w-8 h-8 text-slate-600" />
                            </div>
                          <% end %>
                          <div class="flex-1 min-w-0">
                            <h3 class="font-bold text-white truncate">
                              <%= disk.title || "Unknown Album" %>
                            </h3>
                            <p class="text-sm text-slate-300 truncate">
                              <%= disk.artist || "Unknown Artist" %>
                            </p>
                            <%= if disk.year do %>
                              <p class="text-xs text-slate-500"><%= disk.year %></p>
                            <% end %>
                          </div>
                        </div>
                        <%!-- Available Slots for this disk --%>
                        <div>
                          <p class="text-xs text-slate-400 mb-2">
                            Select an empty slot to load this album:
                          </p>
                          <div class="flex flex-wrap gap-1">
                            <%= for slot <- Enum.filter(@slots, &(is_nil(&1.disk_id))) |> Enum.take(10) do %>
                              <button
                                phx-click="load_disk_to_slot"
                                phx-value-disk_id={disk.id}
                                phx-value-slot_number={slot.slot_number}
                                class="px-3 py-1 bg-blue-600 hover:bg-blue-500 text-white text-sm rounded font-medium transition-colors"
                              >
                                <%= slot.slot_number %>
                              </button>
                            <% end %>
                            <%= if Enum.count(@slots, &is_nil(&1.disk_id)) > 10 do %>
                              <span class="px-3 py-1 text-slate-500 text-sm">
                                +<%= Enum.count(@slots, &is_nil(&1.disk_id)) - 10 %> more
                              </span>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>

            <%!-- Empty Slots Grid --%>
            <div>
              <h3 class="text-sm font-semibold text-slate-400 mb-3 uppercase tracking-wide">
                Empty Slots (<%= Enum.count(@slots, &is_nil(&1.disk_id)) %>)
              </h3>
              <%= if Enum.any?(@slots, &is_nil(&1.disk_id)) do %>
                <div class="grid grid-cols-8 sm:grid-cols-12 md:grid-cols-17 gap-2">
                  <%= for slot <- @slots, is_nil(slot.disk_id) do %>
                    <div class="aspect-square rounded-lg bg-slate-700/50 border border-slate-600 flex items-center justify-center text-slate-400 text-sm font-medium">
                      <%= slot.slot_number %>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-12 text-slate-500">
                  <.icon name="hero-check-circle" class="w-12 h-12 mx-auto mb-3 opacity-50" />
                  <p>All slots are loaded!</p>
                </div>
              <% end %>
            </div>
          </div>

          <% @view_mode == :new_cd -> %>
          <%!-- New CD View --%>
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
                  <div class="relative">
                    <input
                      type="text"
                      phx-change="search_musicbrainz"
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

          <% true -> %>
          <%!-- Default/Changer View --%>
          <div class="bg-slate-800/90 backdrop-blur rounded-2xl shadow-2xl p-6 border border-slate-700">
            <div class="text-center py-12 text-slate-400">
              <.icon name="hero-musical-note" class="w-16 h-16 mx-auto mb-4 opacity-50" />
              <p class="text-lg">Select a view mode above</p>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Album Details Modal --%>
      <%= if @selected_disk do %>
        <div
          class="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          phx-click="close_modal"
        >
          <div
            class="bg-slate-800 rounded-2xl shadow-2xl max-w-2xl w-full border border-slate-700"
            phx-click={JS.exec("phx-remove", to: "#stop-propagation")}
          >
            <div id="stop-propagation" phx-click={JS.exec("phx-remove", to: "#dummy")}>
              <div class="p-6 border-b border-slate-700">
                <div class="flex justify-between items-start">
                  <div class="flex gap-4 flex-1">
                    <%= if @selected_disk.disk.cover_art_url do %>
                      <img
                        src={@selected_disk.disk.cover_art_url}
                        alt={@selected_disk.disk.title}
                        class="w-32 h-32 object-cover rounded-lg shadow-xl"
                      />
                    <% else %>
                      <div class="w-32 h-32 bg-gradient-to-br from-slate-700 to-slate-800 rounded-lg flex items-center justify-center shadow-xl">
                        <.icon name="hero-musical-note" class="w-16 h-16 text-slate-500" />
                      </div>
                    <% end %>
                    <div class="flex-1">
                      <h2 class="text-2xl font-bold text-white mb-1">
                        <%= @selected_disk.disk.title || "Unknown Album" %>
                      </h2>
                      <p class="text-lg text-slate-300 mb-2">
                        <%= @selected_disk.disk.artist || "Unknown Artist" %>
                      </p>
                      <div class="flex items-center gap-3 text-sm text-slate-400">
                        <%= if @selected_disk.disk.year do %>
                          <span><%= @selected_disk.disk.year %></span>
                        <% end %>
                        <%= if @selected_disk.disk.genre do %>
                          <span>•</span>
                          <span><%= @selected_disk.disk.genre %></span>
                        <% end %>
                        <span>•</span>
                        <span>Slot <%= @selected_disk.slot_number %></span>
                      </div>
                    </div>
                  </div>
                  <button
                    phx-click="close_modal"
                    class="text-slate-400 hover:text-white transition-colors ml-4"
                  >
                    <.icon name="hero-x-mark" class="w-6 h-6" />
                  </button>
                </div>
              </div>

              <div class="p-6">
                <%= if @selected_disk.disk.tracks && @selected_disk.disk.tracks != [] do %>
                  <h3 class="text-sm font-semibold text-slate-400 mb-3 uppercase tracking-wide">
                    Tracks
                  </h3>
                  <div class="space-y-1 mb-6 max-h-64 overflow-y-auto">
                    <%= for track <- Enum.sort_by(@selected_disk.disk.tracks, & &1.track_number) do %>
                      <div class="flex items-center gap-3 px-3 py-2 rounded hover:bg-slate-900/50 transition-colors">
                        <span class="text-slate-500 text-sm font-mono w-6 text-right">
                          <%= track.track_number %>.
                        </span>
                        <span class="flex-1 text-white"><%= track.title %></span>
                        <%= if track.duration_seconds do %>
                          <span class="text-slate-400 text-sm font-mono">
                            <%= format_duration(track.duration_seconds) %>
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <button
                  phx-click="unload_disk"
                  phx-value-slot_number={@selected_disk.slot_number}
                  class="w-full px-4 py-3 bg-red-600 hover:bg-red-500 text-white rounded-lg font-semibold transition-colors shadow-lg hover:shadow-red-500/50"
                >
                  <.icon name="hero-trash" class="w-5 h-5 inline mr-2" /> Unload Album
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_duration(_), do: ""
end

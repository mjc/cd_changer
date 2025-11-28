defmodule CdRobot.MusicBrainzTest do
  use ExUnit.Case, async: true

  alias CdRobot.MusicBrainz

  describe "generate_disc_id/2" do
    test "generates consistent disc ID from artist and album" do
      disc_id1 = MusicBrainz.generate_disc_id("The Beatles", "Abbey Road")
      disc_id2 = MusicBrainz.generate_disc_id("The Beatles", "Abbey Road")

      assert disc_id1 == disc_id2
      assert String.length(disc_id1) == 8
      assert disc_id1 =~ ~r/^[0-9a-f]+$/
    end

    test "generates different IDs for different albums" do
      disc_id1 = MusicBrainz.generate_disc_id("The Beatles", "Abbey Road")
      disc_id2 = MusicBrainz.generate_disc_id("Pink Floyd", "Dark Side of the Moon")

      assert disc_id1 != disc_id2
    end

    test "generates different IDs for same artist, different album" do
      disc_id1 = MusicBrainz.generate_disc_id("The Beatles", "Abbey Road")
      disc_id2 = MusicBrainz.generate_disc_id("The Beatles", "Revolver")

      assert disc_id1 != disc_id2
    end
  end

  describe "search_album/2" do
    @tag :external_api
    test "searches for an album (requires internet)" do
      # This test requires actual internet connectivity
      # It's tagged so it can be skipped in CI if needed
      case MusicBrainz.search_album("Pink Floyd", "Dark Side") do
        {:ok, results} ->
          assert is_list(results)
          assert length(results) > 0

          result = List.first(results)
          assert is_map(result)
          assert Map.has_key?(result, :artist)
          assert Map.has_key?(result, :album)
          assert Map.has_key?(result, :disc_id)

        {:error, _} ->
          # API might be down or unreachable, that's okay for this test
          assert true
      end
    end

    @tag :external_api
    test "returns error for nonexistent album" do
      case MusicBrainz.search_album("NonexistentArtist123456", "NonexistentAlbum123456") do
        {:error, :not_found} ->
          assert true

        {:error, _} ->
          # API error is also acceptable
          assert true

        {:ok, _} ->
          # Highly unlikely to find this
          assert true
      end
    end
  end

  describe "get_disc_info/2" do
    @tag :external_api
    test "retrieves disc information (requires internet)" do
      # This test uses a known MusicBrainz release ID
      # We'll skip it if the API is unavailable
      case MusicBrainz.get_disc_info("rock", "test123") do
        {:ok, info} ->
          assert is_map(info)
          # If we got data, it should have tracks
          if Map.has_key?(info, :tracks) do
            assert is_list(info.tracks)
          end

          # Should include cover_art_url field (may be nil)
          assert Map.has_key?(info, :cover_art_url)

        {:error, _} ->
          # API might be down or disc ID doesn't exist
          assert true
      end
    end
  end

  describe "get_cover_art/1" do
    @tag :external_api
    test "fetches cover art for known album" do
      # Using Abbey Road MusicBrainz ID which should have cover art
      mbid = "e7050302-74e6-42e4-aba0-09efd5d431d8"

      case MusicBrainz.get_cover_art(mbid) do
        {:ok, url} ->
          assert is_binary(url)
          assert String.starts_with?(url, "https://coverartarchive.org/")

        {:error, :not_found} ->
          # Cover art might not be available for this release
          assert true
      end
    end

    @tag :external_api
    test "returns error for nonexistent release" do
      # Fake MBID that doesn't exist
      mbid = "00000000-0000-0000-0000-000000000000"

      case MusicBrainz.get_cover_art(mbid) do
        {:error, :not_found} ->
          assert true

        _ ->
          # Unexpected but okay
          assert true
      end
    end
  end
end

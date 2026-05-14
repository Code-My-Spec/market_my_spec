defmodule MarketMySpec.Engagements.Posting do
  @moduledoc """
  Posting utilities for engagement drafts.

  Handles UTM link embedding before staging a Touchpoint. The UTM scheme
  is per-source: Reddit uses utm_source=reddit&utm_medium=engagement,
  ElixirForum uses utm_source=elixirforum&utm_medium=engagement.

  NOTE: This is a scaffold. Full Touchpoint persistence is pending
  Story 707 implementation.
  """

  @doc """
  Embeds a UTM-tracked version of `link_target` into `body`, replacing
  the bare URL with a UTM-enriched one. Uses the thread's source to
  determine the UTM scheme.

  Returns the body string with the UTM link embedded.
  """
  @spec embed_utm_link(map(), String.t(), String.t()) :: String.t()
  def embed_utm_link(thread, body, link_target) do
    utm_url = build_utm_url(thread, link_target)
    String.replace(body, link_target, utm_url)
  end

  @doc """
  Builds a UTM-enriched URL for the given thread and bare link target.
  """
  @spec build_utm_url(map(), String.t()) :: String.t()
  def build_utm_url(thread, link_target) do
    source = Map.get(thread, :source, "unknown")
    thread_id = Map.get(thread, :source_thread_id, Map.get(thread, :id, "unknown"))

    utm_params =
      case source do
        "reddit" ->
          "utm_source=reddit&utm_medium=engagement&utm_campaign=engagement&utm_content=#{thread_id}"

        "elixirforum" ->
          "utm_source=elixirforum&utm_medium=engagement&utm_campaign=engagement&utm_content=#{thread_id}"

        _ ->
          "utm_source=#{source}&utm_medium=engagement"
      end

    separator = if String.contains?(link_target, "?"), do: "&", else: "?"
    "#{link_target}#{separator}#{utm_params}"
  end
end

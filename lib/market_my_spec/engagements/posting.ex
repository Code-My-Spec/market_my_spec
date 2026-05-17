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

  Reddit: utm_source=reddit&utm_medium=comment&utm_campaign=<subreddit>
  ElixirForum: utm_source=elixirforum&utm_medium=reply&utm_campaign=<category-slug>

  The campaign value is extracted from the thread URL:
  - Reddit: path segment after `/r/`
  - ElixirForum: path segment after `/c/` or the subdomain
  Falls back to `source_thread_id` if parsing fails.
  """
  @spec build_utm_url(map(), String.t(), String.t() | nil) :: String.t()
  def build_utm_url(thread, link_target, campaign_override \\ nil) do
    source = Map.get(thread, :source)
    url = Map.get(thread, :url, "")
    explicit_campaign = sanitize_campaign(campaign_override)

    utm_params =
      case source do
        :reddit ->
          campaign =
            explicit_campaign ||
              extract_subreddit(url) ||
              to_string(Map.get(thread, :source_thread_id, "reddit"))

          "utm_source=reddit&utm_medium=comment&utm_campaign=#{campaign}"

        :elixirforum ->
          campaign =
            explicit_campaign ||
              extract_ef_category(url) ||
              to_string(Map.get(thread, :source_thread_id, "elixirforum"))

          "utm_source=elixirforum&utm_medium=reply&utm_campaign=#{campaign}"

        other ->
          src = to_string(other || "unknown")
          base = "utm_source=#{src}&utm_medium=engagement"
          if explicit_campaign, do: base <> "&utm_campaign=#{explicit_campaign}", else: base
      end

    separator = if String.contains?(link_target, "?"), do: "&", else: "?"
    "#{link_target}#{separator}#{utm_params}"
  end

  # Strip whitespace; nil out empty values so the fallback chain triggers.
  # Caller-supplied campaign strings are URI-encoded so a stray space or
  # slash doesn't corrupt the query string.
  defp sanitize_campaign(nil), do: nil

  defp sanitize_campaign(campaign) when is_binary(campaign) do
    case String.trim(campaign) do
      "" -> nil
      trimmed -> URI.encode_www_form(trimmed)
    end
  end

  defp sanitize_campaign(_), do: nil

  # Extract subreddit name from Reddit URL: /r/<subreddit>/...
  defp extract_subreddit(url) do
    case Regex.run(~r{/r/([^/]+)}, url) do
      [_, sub] -> sub
      _ -> nil
    end
  end

  # Extract category slug from ElixirForum URL: /t/<slug>/... or /c/<slug>/...
  defp extract_ef_category(url) do
    case Regex.run(~r{/(?:c|t)/([^/]+)}, url) do
      [_, slug] -> slug
      _ -> nil
    end
  end
end

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
    utm_params = utm_params_for_thread(thread, campaign_override)
    "#{link_target}#{separator(link_target)}#{utm_params}"
  end

  @doc """
  Returns a map of UTM parameter values derived from the thread's source.

  Keys: `:utm_source`, `:utm_medium`, `:utm_campaign`. Used by
  `stage_response` to populate the per-Touchpoint UTM columns; the polish
  step composes the final URL from these args + whatever destination URL
  the model embeds into the polished body.

  Reddit:
    - utm_source: "reddit"
    - utm_medium: "comment"
    - utm_campaign: `<subreddit>:<source_thread_id>` (from Thread.url) or
      override if provided.

  ElixirForum:
    - utm_source: "elixirforum"
    - utm_medium: "reply"
    - utm_campaign: `<category-slug>:<source_thread_id>` (from Thread.url)
      or override.
  """
  @spec build_utm_params(map(), String.t() | nil) :: %{
          utm_source: String.t(),
          utm_medium: String.t(),
          utm_campaign: String.t()
        }
  def build_utm_params(thread, campaign_override \\ nil) do
    case Map.get(thread, :source) do
      :reddit ->
        %{
          utm_source: "reddit",
          utm_medium: "comment",
          utm_campaign: default_or_override(:reddit, thread, campaign_override)
        }

      :elixirforum ->
        %{
          utm_source: "elixirforum",
          utm_medium: "reply",
          utm_campaign: default_or_override(:elixirforum, thread, campaign_override)
        }

      other ->
        %{
          utm_source: to_string(other || "unknown"),
          utm_medium: "engagement",
          utm_campaign: sanitize_campaign(campaign_override) || ""
        }
    end
  end

  defp default_or_override(source, thread, campaign_override) do
    case sanitize_campaign(campaign_override) do
      nil -> default_campaign(source, thread)
      override -> override
    end
  end

  defp default_campaign(:reddit, thread) do
    venue = extract_subreddit(Map.get(thread, :url, "")) || "reddit"
    name = to_string(Map.get(thread, :source_thread_id, "thread"))
    "#{venue}:#{name}"
  end

  defp default_campaign(:elixirforum, thread) do
    venue = extract_ef_category(Map.get(thread, :url, "")) || "elixirforum"
    name = to_string(Map.get(thread, :source_thread_id, "thread"))
    "#{venue}:#{name}"
  end

  defp utm_params_for_thread(thread, campaign_override) do
    source = Map.get(thread, :source)
    url = Map.get(thread, :url, "")
    explicit_campaign = sanitize_campaign(campaign_override)
    utm_params_for(source, url, thread, explicit_campaign)
  end

  defp separator(link_target) do
    if String.contains?(link_target, "?"), do: "&", else: "?"
  end

  defp utm_params_for(:reddit, url, thread, explicit_campaign) do
    campaign =
      explicit_campaign ||
        extract_subreddit(url) ||
        to_string(Map.get(thread, :source_thread_id, "reddit"))

    "utm_source=reddit&utm_medium=comment&utm_campaign=#{campaign}"
  end

  defp utm_params_for(:elixirforum, url, thread, explicit_campaign) do
    campaign =
      explicit_campaign ||
        extract_ef_category(url) ||
        to_string(Map.get(thread, :source_thread_id, "elixirforum"))

    "utm_source=elixirforum&utm_medium=reply&utm_campaign=#{campaign}"
  end

  defp utm_params_for(other, _url, _thread, explicit_campaign) do
    src = to_string(other || "unknown")
    base = "utm_source=#{src}&utm_medium=engagement"
    if explicit_campaign, do: base <> "&utm_campaign=#{explicit_campaign}", else: base
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

defmodule MarketMySpecSpex.Story707.Criterion6206Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6206 — v1 does not support programmatic posting; both Reddit and ElixirForum
  are read-only via public APIs.

  The Source adapters for Reddit and ElixirForum return {:error, :posting_not_supported}
  when post/3 is called. The UI shows "Copy to clipboard" instead of a "Post" button
  because posting is not available programmatically in v1.

  Both adapters are deliberately read-only in v1 — programmatic posting requires
  OAuth write scopes that are not part of the current integration surface.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Source.ElixirForum

  spex "v1 source adapters do not support programmatic posting" do
    scenario "Reddit.post/3 returns posting_not_supported error" do
      given_ "no special setup required", context do
        {:ok, context}
      end

      when_ "Reddit.post/3 is called with any credential and thread", _context do
        result = Reddit.post(nil, "abc123", "Hello world")
        {:ok, %{result: result}}
      end

      then_ "it returns {:error, :posting_not_supported}", context do
        assert context.result == {:error, :posting_not_supported},
               "expected Reddit.post/3 to return {:error, :posting_not_supported}, got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "ElixirForum.post/3 returns posting_not_supported error" do
      given_ "no special setup required", context do
        {:ok, context}
      end

      when_ "ElixirForum.post/3 is called with any credential and topic", _context do
        result = ElixirForum.post(nil, "123", "Hello ElixirForum")
        {:ok, %{result: result}}
      end

      then_ "it returns {:error, :posting_not_supported}", context do
        assert context.result == {:error, :posting_not_supported},
               "expected ElixirForum.post/3 to return {:error, :posting_not_supported}, got: #{inspect(context.result)}"

        {:ok, context}
      end
    end
  end
end

defmodule MarketMySpecSpex.Story714.Criterion6391Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6391 — `validate_venue` accepts `category-slug` and
  `category-slug:tag`; rejects malformed.

  Pure module-level contract on the ElixirForum adapter. No HTTP,
  no cassette — direct calls to `validate_venue/1` with a
  representative set of inputs.

  Interaction surface: Module-level validation (called by saved-search
  tool + adapter on each request).
  """

  use MarketMySpecSpex.Case

  spex "validate_venue accepts category-slug and category-slug:tag; rejects malformed" do
    scenario "Round-trip representative accept/reject cases through validate_venue/1" do
      given_ "the ElixirForum adapter's validate_venue function", context do
        adapter = MarketMySpec.Engagements.Source.ElixirForum

        assert Code.ensure_loaded?(adapter),
               "expected adapter #{inspect(adapter)} to be loaded"

        assert function_exported?(adapter, :validate_venue, 1),
               "expected adapter to export validate_venue/1"

        {:ok, Map.put(context, :adapter, adapter)}
      end

      when_ "validate_venue is called with valid and invalid identifiers", context do
        accept_cases = [
          "phoenix",
          "elixir",
          "phoenix:livebook",
          "elixir:phoenix-1-7",
          "questions"
        ]

        reject_cases = [
          "",
          "   ",
          "/phoenix",
          "phoenix/",
          "phoenix livebook",
          "phoenix:",
          ":livebook",
          "phoenix:livebook:extra",
          "https://elixirforum.com/c/phoenix/3"
        ]

        results = %{
          accepted: Enum.map(accept_cases, fn id -> {id, context.adapter.validate_venue(id)} end),
          rejected: Enum.map(reject_cases, fn id -> {id, context.adapter.validate_venue(id)} end)
        }

        {:ok, Map.put(context, :results, results)}
      end

      then_ "valid forms return :ok / {:ok, _}; invalid forms return {:error, _}", context do
        for {id, result} <- context.results.accepted do
          case result do
            :ok -> :ok
            {:ok, _} -> :ok
            other -> flunk("expected #{inspect(id)} to be accepted, got: #{inspect(other)}")
          end
        end

        for {id, result} <- context.results.rejected do
          case result do
            {:error, _} -> :ok
            :error -> :ok
            other -> flunk("expected #{inspect(id)} to be rejected, got: #{inspect(other)}")
          end
        end

        {:ok, context}
      end
    end
  end
end

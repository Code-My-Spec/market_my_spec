defmodule MarketMySpec.Linter.TestStub do
  @moduledoc """
  Deterministic in-memory `Linter` implementation used in the test environment.

  Encodes a small rule-set sufficient to drive the spex contracts:

    * `validate_config/1` accepts any `.vale.ini` that contains at least one
      format section header (`[*]`, `[*.md]`, etc.). Anything else is treated
      as a structural error from `ls-config`.

    * `lint/2` flags every occurrence of the word "very" when the config
      enables `write-good` (`BasedOnStyles = write-good` or `Packages = write-good`).
      Every other config produces zero alerts. This is enough to differentiate
      "no alerts" from "some alerts" without spinning up the real Vale binary.

  Production traffic goes through `MarketMySpec.Linter.Vale`. The implementation
  is swapped via `Application.get_env(:market_my_spec, :linter_impl, ...)`.
  """

  @behaviour MarketMySpec.Linter.Linter

  @impl true
  def validate_config(vale_ini) when is_binary(vale_ini) do
    case Regex.match?(~r/^\s*\[\*[^\]]*\]\s*$/m, vale_ini) do
      true -> :ok
      false -> {:error, "vale config error: no format section header found (e.g. [*] or [*.md])"}
    end
  end

  @impl true
  def lint(vale_ini, prose) when is_binary(vale_ini) and is_binary(prose) do
    case enables_write_good?(vale_ini) do
      true -> {:ok, find_weasel_words(prose)}
      false -> {:ok, []}
    end
  end

  defp enables_write_good?(vale_ini) do
    Regex.match?(~r/\bwrite-good\b/, vale_ini)
  end

  defp find_weasel_words(prose) do
    prose
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(&weasel_alerts_for_line/1)
  end

  defp weasel_alerts_for_line({line, line_no}) do
    line
    |> find_positions("very")
    |> Enum.map(fn column ->
      %{
        severity: "warning",
        check: "write-good.Weasel",
        line: line_no,
        column: column,
        message: "'very' is a weasel word and can almost always be removed"
      }
    end)
  end

  defp find_positions(string, needle) do
    needle_len = String.length(needle)

    Stream.unfold({string, 1}, fn
      {"", _offset} ->
        nil

      {chunk, offset} ->
        case :binary.match(chunk, needle) do
          :nomatch ->
            nil

          {idx, _} ->
            column = offset + idx
            remaining = String.slice(chunk, (idx + needle_len)..-1//1) || ""
            {column, {remaining, column + needle_len}}
        end
    end)
    |> Enum.to_list()
  end
end

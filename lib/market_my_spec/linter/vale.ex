defmodule MarketMySpec.Linter.Vale do
  @moduledoc """
  Vale CLI implementation of `MarketMySpec.Linter.Linter`.

  Materializes a `.vale.ini` body to a fresh temp directory, rewriting its
  `StylesPath` to the absolute path of the vendored styles tree baked into
  the Docker image. Shells out to `vale` for both `ls-config` validation
  (config-save time) and JSON-output linting (polish time).

  The styles path defaults to `/app/priv/vale/styles` (the Docker image path)
  but can be overridden via the `VALE_STYLES_PATH` environment variable for
  local development.

  See `.code_my_spec/architecture/decisions/vale.md` for the runtime model
  and `.code_my_spec/knowledge/vale-cli.md` for the CLI reference.
  """

  @behaviour MarketMySpec.Linter.Linter

  @default_vendored_styles_path "/app/priv/vale/styles"

  @impl true
  def validate_config(vale_ini) when is_binary(vale_ini) do
    with_materialized_config(vale_ini, fn dir ->
      config_path = Path.join(dir, ".vale.ini")

      case System.cmd(vale_bin(), ["--config", config_path, "ls-config"],
             stderr_to_stdout: true
           ) do
        {_output, 0} -> :ok
        {error_output, _} -> {:error, String.trim(error_output)}
      end
    end)
  end

  @impl true
  def lint(vale_ini, prose) when is_binary(vale_ini) and is_binary(prose) do
    with_materialized_config(vale_ini, fn dir ->
      config_path = Path.join(dir, ".vale.ini")
      prose_path = Path.join(dir, "prose.md")
      File.write!(prose_path, prose)

      args = [
        "--config",
        config_path,
        "--output",
        "JSON",
        "--no-exit",
        "--no-global",
        prose_path
      ]

      case System.cmd(vale_bin(), args, stderr_to_stdout: false) do
        {output, exit_code} when exit_code in [0, 1] ->
          parse_alerts(output, prose_path)

        {error_output, _} ->
          {:error, String.trim(error_output)}
      end
    end)
  end

  defp with_materialized_config(vale_ini, fun) do
    dir = Path.join(System.tmp_dir!(), "vale-#{random_suffix()}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".vale.ini"), rewrite_styles_path(vale_ini))

    try do
      fun.(dir)
    after
      File.rm_rf!(dir)
    end
  end

  defp random_suffix do
    8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
  end

  defp rewrite_styles_path(vale_ini) do
    path = System.get_env("VALE_STYLES_PATH", @default_vendored_styles_path)
    line = "StylesPath = #{path}"

    case Regex.match?(~r/^\s*StylesPath\s*=.+$/m, vale_ini) do
      true -> Regex.replace(~r/^\s*StylesPath\s*=.+$/m, vale_ini, line)
      false -> line <> "\n" <> vale_ini
    end
  end

  defp parse_alerts(json, prose_path) do
    case Jason.decode(json) do
      {:ok, decoded} when is_map(decoded) ->
        flat =
          decoded
          |> Map.get(prose_path, [])
          |> Enum.map(&flatten_alert/1)

        {:ok, flat}

      _ ->
        {:ok, []}
    end
  end

  defp flatten_alert(alert) do
    %{
      severity: Map.get(alert, "Severity", "warning"),
      check: Map.get(alert, "Check", ""),
      line: Map.get(alert, "Line", 1),
      column: alert |> Map.get("Span", [1, 1]) |> List.first(),
      message: Map.get(alert, "Message", "")
    }
  end

  defp vale_bin do
    System.get_env("VALE_BIN") || "vale"
  end
end

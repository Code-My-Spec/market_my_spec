defmodule MarketMySpecAgent.Auth do
  @moduledoc """
  Reads and writes the paired-agent credential file.

  ## Path resolution

  The credential file lives under `~/.mms-agent/`. Which file inside
  that directory is read or written is determined by, in order:

  1. **Runtime env override** (set by `MarketMySpecAgent.CLI` from the
     `--env NAME` flag or `MMS_AGENT_ENV` env var): writes
     `~/.mms-agent/auth.<env>.json`. This is how the same Burrito binary
     pairs separately against UAT, dev, prod, etc. on the same machine.

  2. **Compile-time default** (set via
     `config :market_my_spec, :agent_token_path`): the original
     per-MIX_ENV split — `prod_agent` → `~/.mms-agent/auth.json`,
     `dev_agent` → `~/.mms-agent/auth.dev.json`. Used when no `--env`
     flag is passed, which keeps existing brew installs talking to the
     same prod server they were paired against.

  Shape:

      {
        "agent_id":   "uuid",
        "token":      "opaque long-lived token issued by /agents/pair",
        "server_url": "https://mms.example.com",
        "paired_at":  "2026-05-19T18:30:00Z"
      }
  """

  @default_path "~/.mms-agent/auth.json"

  @doc """
  Absolute path to the credential file.

  Runtime env override (set via `Application.put_env(:market_my_spec,
  :agent_env_override, "uat")`) wins. Otherwise falls back to the
  compile-time configured path.
  """
  def path do
    case Application.get_env(:market_my_spec, :agent_env_override) do
      env when is_binary(env) and env != "" ->
        Path.expand("~/.mms-agent/auth.#{env}.json")

      _ ->
        :market_my_spec
        |> Application.get_env(:agent_token_path, @default_path)
        |> Path.expand()
    end
  end

  @doc "Absolute path to the credential directory (parent of `path/0`)."
  def dir, do: Path.dirname(path())

  @doc """
  Reads the credential file. Returns `{:ok, map}` or
  `{:error, :missing | :unreadable | :invalid_json}`.
  """
  def read do
    case File.read(path()) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{} = creds} -> {:ok, creds}
          _ -> {:error, :invalid_json}
        end

      {:error, :enoent} ->
        {:error, :missing}

      {:error, _} ->
        {:error, :unreadable}
    end
  end

  @doc """
  Writes the credential file with mode 0600. Creates the parent
  directory if needed (also 0700).
  """
  def write(%{} = creds) do
    File.mkdir_p!(dir())
    File.chmod!(dir(), 0o700)

    File.write!(path(), Jason.encode!(creds))
    File.chmod!(path(), 0o600)
    :ok
  end
end

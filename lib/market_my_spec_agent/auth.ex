defmodule MarketMySpecAgent.Auth do
  @moduledoc """
  Reads and writes the paired-agent credential file.

  Path is configured per env via `config :market_my_spec, :agent_token_path`:

    * `prod_agent` → `~/.mms-agent/auth.json` (shipped Burrito binary)
    * `dev_agent`  → `~/.mms-agent/auth.dev.json` (in-tree `just agent`)

  Separate files mean a developer can pair against `http://localhost:4007`
  without clobbering production credentials, and vice versa. `~` is
  expanded against the current user's home.

  Shape:

      {
        "agent_id":   "uuid",
        "token":      "opaque long-lived token issued by /agents/pair",
        "server_url": "https://mms.example.com",
        "paired_at":  "2026-05-19T18:30:00Z"
      }
  """

  @default_path "~/.mms-agent/auth.json"

  @doc "Absolute path to the credential file (env-configured)."
  def path do
    :market_my_spec
    |> Application.get_env(:agent_token_path, @default_path)
    |> Path.expand()
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

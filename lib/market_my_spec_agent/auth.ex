defmodule MarketMySpecAgent.Auth do
  @moduledoc """
  Reads and writes the paired-agent credential file.

  Path: `~/.mms-agent/auth.json` (mode 0600).

  Shape:

      {
        "agent_id":   "uuid",
        "token":      "opaque long-lived token issued by /agents/pair",
        "server_url": "https://mms.example.com",
        "paired_at":  "2026-05-19T18:30:00Z"
      }
  """

  @doc "Absolute path to the credential file."
  def path do
    Path.join(System.user_home!(), ".mms-agent/auth.json")
  end

  @doc "Absolute path to the credential directory."
  def dir do
    Path.join(System.user_home!(), ".mms-agent")
  end

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

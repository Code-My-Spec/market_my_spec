defmodule MarketMySpecAgent.CLI do
  @moduledoc """
  Burrito entry point for the `mms-agent` binary. Parses argv and
  dispatches to a subcommand.
  """

  alias MarketMySpecAgent.Auth
  alias MarketMySpecAgent.Pairing

  @doc """
  Entry point. Returns an integer exit code.

  Subcommands:
    * `pair`   — run the first-run browser pairing flow
    * `status` — print pairing state
  """
  def main(argv \\ nil) do
    args = (argv || burrito_argv()) |> Enum.reject(&(&1 == "--"))

    maybe_version_check(args)
    dispatch(args)
  end

  # Phone-home version check (soft-fails, cached 24h). Skipped for
  # `server` mode so the long-running process doesn't block on it,
  # and for `help` since the user is just discovering commands.
  defp maybe_version_check([head | _]) when head in ["pair", "status"] do
    MarketMySpecAgent.VersionCheck.maybe_notify()
  end

  defp maybe_version_check(_args), do: :ok

  defp dispatch(["pair" | _]), do: cmd_pair()
  defp dispatch(["status" | _]), do: cmd_status()
  defp dispatch(["server" | _]), do: cmd_server()
  defp dispatch(_), do: cmd_help()

  defp cmd_server do
    case MarketMySpecAgent.Auth.read() do
      {:ok, creds} ->
        IO.puts("mms-agent: server mode — joining #{creds["server_url"]} as agent #{creds["agent_id"]}")
        IO.puts("Ctrl-C to stop.")
        Process.sleep(:infinity)

      {:error, :missing} ->
        IO.puts(:stderr, "mms-agent: not paired. Run `mms-agent pair` first.")
        1

      {:error, reason} ->
        IO.puts(:stderr, "mms-agent: could not read credentials (#{reason})")
        1
    end
  end

  defp cmd_pair do
    case Pairing.run() do
      :ok ->
        IO.puts("mms-agent: paired. Token saved to #{Auth.path()}.")
        0

      {:error, :denied} ->
        IO.puts(:stderr, "mms-agent: pairing denied.")
        1

      {:error, :timeout} ->
        IO.puts(:stderr, "mms-agent: pairing timed out after 5 minutes.")
        1

      {:error, reason} ->
        IO.puts(:stderr, "mms-agent: pairing failed (#{inspect(reason)}).")
        1
    end
  end

  defp cmd_status do
    case Auth.read() do
      {:ok, creds} ->
        IO.puts("paired: yes")
        IO.puts("agent_id: #{creds["agent_id"]}")
        IO.puts("server:   #{creds["server_url"]}")
        IO.puts("paired_at: #{creds["paired_at"]}")
        0

      {:error, :missing} ->
        IO.puts("paired: no")
        IO.puts("run `mms-agent pair` to set up")
        1

      {:error, reason} ->
        IO.puts(:stderr, "mms-agent: could not read credentials (#{reason})")
        1
    end
  end

  defp cmd_help do
    IO.puts("""
    mms-agent — local pairing companion for Market My Spec

      mms-agent pair      Open browser to pair this binary with your account
      mms-agent server    Stay running and serve requests from the MMS server
      mms-agent status    Print pairing state
      mms-agent help      Show this message
    """)

    0
  end

  @doc false
  def burrito_argv do
    # apply/3 is intentional: Burrito.Util.Args may not exist at compile time
    # (the module is only present in the packaged binary). We guard with
    # Code.ensure_loaded? + function_exported? before calling.
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    if Code.ensure_loaded?(Burrito.Util.Args) and function_exported?(Burrito.Util.Args, :argv, 0) do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Burrito.Util.Args, :argv, [])
    else
      []
    end
  end
end

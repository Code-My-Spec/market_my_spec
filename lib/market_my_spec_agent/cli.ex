defmodule MarketMySpecAgent.CLI do
  @moduledoc """
  Burrito entry point for the `mms-agent` binary. Parses argv and
  dispatches to a subcommand.

  ## `--env` flag

  All subcommands accept `--env NAME` (or `--env=NAME`) to target a
  separate per-env credential file under `~/.mms-agent/auth.<env>.json`.
  Without the flag, the binary uses the compile-time default path
  (typically `~/.mms-agent/auth.json` for the brew-shipped binary).

  `MMS_AGENT_ENV` env var is the secondary input — useful in per-env
  shell profiles. The CLI flag wins when both are present.

  Example: pair against UAT without touching the prod pairing:

      mms-agent --env uat pair
      mms-agent --env uat server

  See `MarketMySpecAgent.Auth` for the path-resolution rules.
  """

  alias MarketMySpecAgent.Auth
  alias MarketMySpecAgent.Pairing

  @doc """
  Entry point. Returns an integer exit code.

  Subcommands:
    * `pair`   — run the first-run browser pairing flow
    * `server` — stay running and serve dispatched requests
    * `status` — print pairing state
    * `help`   — show usage

  Flags:
    * `--env NAME` — target the `<NAME>` env's credential file
  """
  def main(argv \\ nil) do
    raw_argv = argv || burrito_argv()
    {env, args} = parse_env_flag(raw_argv)

    apply_env_override(env)

    args = Enum.reject(args, &(&1 == "--"))

    maybe_version_check(args)
    dispatch(args)
  end

  @doc """
  Extracts `--env NAME` / `--env=NAME` from argv. Returns
  `{env_name_or_nil, remaining_argv}`.

  Also called from `MarketMySpecAgent.Application.start/2` so the env
  override is applied before `Auth.Store` boots and reads its initial
  credentials.
  """
  @spec parse_env_flag([String.t()]) :: {String.t() | nil, [String.t()]}
  def parse_env_flag(argv) do
    do_parse_env(argv, [], nil)
  end

  defp do_parse_env([], acc, env), do: {env, Enum.reverse(acc)}

  defp do_parse_env(["--env=" <> name | rest], acc, _) when name != "" do
    do_parse_env(rest, acc, name)
  end

  defp do_parse_env(["--env", name | rest], acc, _) when name != "" do
    do_parse_env(rest, acc, name)
  end

  defp do_parse_env([head | rest], acc, env) do
    do_parse_env(rest, [head | acc], env)
  end

  @doc """
  Applies the env override into Application config. Idempotent.

  Lookup order: explicit `env` arg wins, then `MMS_AGENT_ENV` env var,
  then nothing (preserves the compile-time path).
  """
  def apply_env_override(env) do
    resolved = env || System.get_env("MMS_AGENT_ENV")

    case resolved do
      nil ->
        Application.delete_env(:market_my_spec, :agent_env_override)

      "" ->
        Application.delete_env(:market_my_spec, :agent_env_override)

      name when is_binary(name) ->
        Application.put_env(:market_my_spec, :agent_env_override, name)
    end

    :ok
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
    IO.puts("env:      #{active_env_label()}")
    IO.puts("path:     #{Auth.path()}")

    case Auth.read() do
      {:ok, creds} ->
        IO.puts("paired:   yes")
        IO.puts("agent_id: #{creds["agent_id"]}")
        IO.puts("server:   #{creds["server_url"]}")
        IO.puts("paired_at: #{creds["paired_at"]}")
        0

      {:error, :missing} ->
        IO.puts("paired:   no")
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

    Flags:
      --env NAME          Target a per-env credential file
                          (~/.mms-agent/auth.<NAME>.json).
                          Lets one binary pair separately against
                          prod, uat, dev, etc.
                          MMS_AGENT_ENV is the env-var equivalent.
    """)

    0
  end

  defp active_env_label do
    case Application.get_env(:market_my_spec, :agent_env_override) do
      env when is_binary(env) and env != "" -> env
      _ -> "(default)"
    end
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

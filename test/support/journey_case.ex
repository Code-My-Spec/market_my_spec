defmodule MarketMySpecWeb.JourneyCase do
  @moduledoc """
  Case template for end-to-end journey tests that exercise a real
  deployed environment (dev / uat / prod) instead of an in-process
  Phoenix endpoint with the SQL sandbox.

  Differs from `MarketMySpecWeb.FeatureCase`:

    * No `Phoenix.Ecto.SQL.Sandbox` — we're talking to a remote DB we
      can't roll back. Tests must be idempotent or self-cleaning.
    * Wallaby session is pre-loaded with cookies from
      `.code_my_spec/qa/sessions/<env>.json` so the operator's signed-in
      state is reused. See `.code_my_spec/qa/sessions/SETUP.md` for how
      to capture those.
    * Brings in `MarketMySpec.JourneyHelpers` for MCP-bearer minting,
      MCP client startup, and `mms-agent` binary lifecycle.

  ## Usage

      use MarketMySpecWeb.JourneyCase, env: :uat

      @moduletag :journey
      @moduletag :uat   # opt-in via `mix test --include uat`

      feature "Journey N — ...", %{session: session, env: env} do
        # session is Wallaby, signed-in via restored cookies.
        # env is the atom (:dev | :uat | :prod) — pass to JourneyHelpers
        # for base-url-aware MCP / OAuth calls.
      end
  """

  use ExUnit.CaseTemplate

  alias MarketMySpec.JourneyHelpers

  using opts do
    env = Keyword.fetch!(opts, :env)

    quote do
      use Wallaby.Feature

      alias MarketMySpec.JourneyHelpers

      @journey_env unquote(env)

      # Runs AFTER Wallaby.Feature's setup, which puts `session:` in context.
      # We restore the operator's captured cookies into THAT session — not
      # into a fresh ghost session — so the test actually drives the
      # signed-in browser.
      setup %{session: session} = _context do
        base = JourneyHelpers.base_url(@journey_env)
        Application.put_env(:wallaby, :base_url, base)

        on_exit(fn -> JourneyHelpers.kill_agent_binary() end)

        case JourneyHelpers.restore_session_into(session, @journey_env) do
          {:ok, session} -> {:ok, session: session, env: @journey_env, base_url: base}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end

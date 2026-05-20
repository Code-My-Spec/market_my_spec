# MarketMySpecAgent.CLI

Burrito entry point for the `mms-agent` binary. `main/1` is called by the Burrito runtime after the OTP supervision tree is up; it receives `argv` (also retrievable via `Burrito.Util.Args.argv/0`) and returns an integer exit code. Subcommand dispatch is handled via Optimus with four defined subcommands: `pair` runs `MarketMySpecAgent.Pairing.run/1` — if pairing succeeds, prints a confirmation line and returns 0; if it returns `{:error, :denied}`, prints a denial message and returns 1; if `{:error, :timeout}`, prints a timeout message and returns 1. `server` starts the long-running supervised mode (the channel client loop) — this subcommand is also the implicit default when the binary is already paired and no subcommand is given; it blocks until the process is signaled. `status` calls `Auth.Store.get/0` and prints whether the binary is paired (printing agent_id and server_url) or unpaired, then checks channel connection state and prints online/offline; returns 0 always. `whoami` calls `Auth.Store.get/0` and prints the `agent_id` and `server_url` fields if paired, or an "not paired" message with a hint to run `mms-agent pair` if unpaired; returns 0 always. Unrecognized subcommands print Optimus-generated help and return 1. No subcommand dispatch logic lives outside this module — each subcommand delegates immediately to its owning module.

## Type

module

## Dependencies

- MarketMySpecAgent.Pairing
- MarketMySpecAgent.Auth.Store
- MarketMySpecAgent.Channel.Client

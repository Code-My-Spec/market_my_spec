defmodule MarketMySpecAgent.Release.PatchLauncherStep do
  @moduledoc """
  Burrito build step that patches the Zig launcher to inject `--`
  before user arguments.

  Without this, Elixir's `start_cli` interprets the binary's argv as
  script file paths. The `--` separator stops option processing so
  the application can read its real argv via
  `Burrito.Util.Args.argv()`.

  Lifted verbatim from `CodeMySpecCli.Release.PatchLauncherStep` in
  the code_my_spec repo — same Burrito version, same Zig source.
  """

  @behaviour Burrito.Builder.Step

  @impl true
  def execute(%Burrito.Builder.Context{} = context) do
    IO.puts("\n[PatchLauncherStep] Patching Zig launcher to add -- separator...")

    burrito_path = context.self_dir
    launcher_path = Path.join([burrito_path, "src", "erlang_launcher.zig"])

    IO.puts("[PatchLauncherStep] Launcher path: #{launcher_path}")

    if File.exists?(launcher_path) do
      content = File.read!(launcher_path)

      if String.contains?(content, "\"--\",  // Added by PatchLauncherStep") do
        IO.puts("[PatchLauncherStep] Already patched, skipping")
      else
        patched_content =
          String.replace(
            content,
            ~s|"-extra",\n    };|,
            ~s|"-extra",\n        "--",  // Added by PatchLauncherStep\n    };|
          )

        if patched_content != content do
          File.write!(launcher_path, patched_content)
          IO.puts("[PatchLauncherStep] Successfully patched launcher")
        else
          IO.puts("[PatchLauncherStep] WARNING: Could not find pattern to patch")
        end
      end
    else
      IO.puts("[PatchLauncherStep] WARNING: Launcher file not found at #{launcher_path}")
    end

    context
  end
end

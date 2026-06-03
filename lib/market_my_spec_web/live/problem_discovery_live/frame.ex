defmodule MarketMySpecWeb.ProblemDiscoveryLive.Frame do
  @moduledoc """
  Frame detail with inline Board (story 739).

  Per-stage artifact summary and the killable-in-one-click Candidates
  table. Each Candidate row shows label, score, verdict (with four-way
  data-verdict tag for the spex), kill_argument, and a kill button that
  overwrites the verdict to `:kill`. Action buttons trigger pipeline
  reruns directly (the agent does the same via MCP tools).

  Empty-Gather notice surfaces when the Frame's Gather has run with zero
  results across all saved searches (criterion 6536).
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.ProblemDiscovery

  @impl true
  def mount(%{"id" => frame_id}, _session, socket) do
    case ProblemDiscovery.get_frame(socket.assigns.current_scope, frame_id) do
      {:ok, frame} ->
        {:ok, load_board(assign(socket, :frame, frame))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Frame not found")
         |> push_navigate(to: ~p"/problem-discovery/frames")}
    end
  end

  @impl true
  def handle_event("run_gather", _, socket) do
    {:noreply,
     run_and_reload(socket, fn ->
       ProblemDiscovery.run_gather(socket.assigns.current_scope, socket.assigns.frame.id)
     end)}
  end

  @impl true
  def handle_event("run_cluster", _, socket) do
    {:noreply,
     run_and_reload(socket, fn ->
       ProblemDiscovery.run_cluster(socket.assigns.current_scope, socket.assigns.frame.id)
     end)}
  end

  @impl true
  def handle_event("run_score", _, socket) do
    {:noreply,
     run_and_reload(socket, fn ->
       ProblemDiscovery.run_score(socket.assigns.current_scope, socket.assigns.frame.id)
     end)}
  end

  @impl true
  def handle_event("kill", %{"candidate-id" => candidate_id}, socket) do
    attrs = %{
      verdict: :kill,
      kill_argument: "Killed by founder from the Board",
      cheapest_kill_test: "n/a — founder-killed from the Board"
    }

    case ProblemDiscovery.red_team_candidate(
           socket.assigns.current_scope,
           candidate_id,
           attrs
         ) do
      {:ok, _} -> {:noreply, load_board(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Kill failed")}
    end
  end

  defp run_and_reload(socket, fun) do
    case fun.() do
      {:ok, _} -> load_board(socket)
      {:error, reason} -> put_flash(socket, :error, "Stage failed: #{inspect(reason)}")
    end
  end

  defp load_board(socket) do
    case ProblemDiscovery.get_board(socket.assigns.current_scope, socket.assigns.frame.id) do
      {:ok, view} ->
        assign(socket,
          board: view,
          empty_gather?: view.corpus_health.total_postings == 0 and gather_attempted?(view)
        )

      {:error, _} ->
        assign(socket, :board, nil)
    end
  end

  defp gather_attempted?(%{frame: %{saved_searches: searches}}) when is_list(searches) do
    Enum.any?(searches, fn
      %{"gathered_at" => ts} when is_binary(ts) -> true
      %{gathered_at: ts} when is_binary(ts) -> true
      _ -> false
    end)
  end

  defp gather_attempted?(_view), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl py-8">
        <.link navigate={~p"/problem-discovery/frames"} class="text-sm link link-hover">
          ← All Frames
        </.link>

        <header class="mt-4 flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-semibold">{@frame.description}</h1>
            <p class="text-sm text-base-content/60 mt-1">
              {length(@frame.saved_searches)} saved searches •
              total_spent_min: ${money_gate_field(@frame.money_gate, :total_spent_min)} •
              hire_rate_min: {money_gate_field(@frame.money_gate, :hire_rate_min)}%
            </p>
          </div>

          <div class="flex gap-2">
            <button class="btn btn-sm" phx-click="run_gather">Run Gather</button>
            <button class="btn btn-sm" phx-click="run_cluster">Run Cluster</button>
            <button class="btn btn-sm" phx-click="run_score">Run Score</button>
          </div>
        </header>

        <div :if={@empty_gather?} class="mt-6 alert alert-warning" data-test="empty-gather-notice">
          Gather returned zero postings across all saved searches. Pipeline halted —
          revise the saved searches and re-run Gather.
        </div>

        <%= if @board do %>
          <section class="mt-8">
            <h2 class="text-lg font-medium mb-2">Corpus Health</h2>
            <div class="rounded border border-base-300 p-4 text-sm grid grid-cols-3 gap-4">
              <div>
                <div class="text-base-content/60">Total postings</div>
                <div class="text-2xl font-semibold">{@board.corpus_health.total_postings}</div>
              </div>
              <div>
                <div class="text-base-content/60">Gated-in</div>
                <div class="text-2xl font-semibold">{@board.corpus_health.postings_gated_in}</div>
              </div>
              <div>
                <div class="text-base-content/60">Distinct strong clients</div>
                <div class="text-2xl font-semibold">
                  {@board.corpus_health.distinct_clients_in_keep_tier}
                </div>
              </div>
            </div>

            <div
              :if={@board.kill_condition_status == :not_met}
              class="mt-4 alert alert-error text-sm"
              data-test="kill-condition-not-met"
            >
              kill_condition NOT met. Per your Frame's pre-commitment, this hypothesis is a NO.
            </div>
          </section>

          <section class="mt-8">
            <h2 class="text-lg font-medium mb-2">Board</h2>

            <%= if @board.candidates == [] do %>
              <div class="rounded border border-base-300 p-6 text-base-content/70 text-sm">
                No surviving Candidates yet. Run the pipeline (Gather → Cluster → Score → Red-team)
                to populate the Board.
              </div>
            <% else %>
              <ul class="space-y-3" data-test="board-list">
                <li
                  :for={c <- @board.candidates}
                  data-test="board-row"
                  data-verdict={verdict_attr(c.red_team_verdict)}
                  class="rounded border border-base-300 p-4"
                >
                  <div class="flex items-start justify-between gap-4">
                    <div class="flex-1">
                      <p class="font-medium">{c.label || "(unlabeled)"}</p>
                      <p class="text-sm text-base-content/60">
                        score: {c.score} •
                        verdict: <span class="font-mono">{verdict_attr(c.red_team_verdict) || "(none)"}</span>
                      </p>
                      <p
                        :if={c.red_team_verdict && c.red_team_verdict.kill_argument}
                        class="text-sm text-base-content/70 mt-2"
                      >
                        <strong>kill_argument:</strong> {c.red_team_verdict.kill_argument}
                      </p>
                    </div>
                    <button
                      class="btn btn-sm btn-error"
                      phx-click="kill"
                      phx-value-candidate-id={c.id}
                      data-test="kill-button"
                    >
                      KILL
                    </button>
                  </div>
                </li>
              </ul>
            <% end %>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp money_gate_field(%{"total_spent_min" => v}, :total_spent_min), do: v
  defp money_gate_field(%{total_spent_min: v}, :total_spent_min), do: v
  defp money_gate_field(%{"hire_rate_min" => v}, :hire_rate_min), do: v
  defp money_gate_field(%{hire_rate_min: v}, :hire_rate_min), do: v
  defp money_gate_field(_, _), do: "?"

  defp verdict_attr(nil), do: nil
  defp verdict_attr(%Ecto.Association.NotLoaded{}), do: nil
  defp verdict_attr(%{verdict: v}) when is_atom(v), do: Atom.to_string(v)
  defp verdict_attr(%{verdict: v}) when is_binary(v), do: v
end

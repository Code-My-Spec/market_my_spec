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
        {:ok,
         socket
         |> assign(:frame, frame)
         |> assign(:expanded_candidates, MapSet.new())
         |> load_board()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Frame not found")
         |> push_navigate(to: ~p"/app/problem-discovery/frames")}
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
  def handle_event("toggle_postings", %{"candidate-id" => candidate_id}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded_candidates, candidate_id) do
        MapSet.delete(socket.assigns.expanded_candidates, candidate_id)
      else
        MapSet.put(socket.assigns.expanded_candidates, candidate_id)
      end

    {:noreply, assign(socket, :expanded_candidates, expanded)}
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
        <.link navigate={~p"/app/problem-discovery/frames"} class="text-sm link link-hover">
          ← All Frames
        </.link>

        <header class="mt-4 flex items-start justify-between gap-6">
          <div class="flex-1 min-w-0">
            <h1 class="text-2xl font-semibold truncate">{@frame.title || @frame.description}</h1>
            <p :if={@frame.title && @frame.description} class="text-sm text-base-content/80 mt-2">
              {@frame.description}
            </p>
            <p class="text-xs text-base-content/60 mt-2">
              {length(@frame.saved_searches)} saved searches •
              total_spent_min: ${money_gate_field(@frame.money_gate, :total_spent_min)} •
              hire_rate_min: {money_gate_field(@frame.money_gate, :hire_rate_min)}%
            </p>
          </div>

          <div class="flex gap-2 shrink-0">
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

            <%= if @board.candidates == [] and (Map.get(@board, :pending_candidates) || []) == [] do %>
              <div class="rounded border border-base-300 p-6 text-base-content/70 text-sm">
                No surviving Candidates yet. Run the pipeline (Gather → Cluster → Score → Red-team)
                to populate the Board.
              </div>
            <% else %>
              <ul class="space-y-3" data-test="board-list">
                <li
                  :for={c <- order_candidates(@board.candidates)}
                  data-test="board-row"
                  data-verdict={verdict_attr(c.red_team_verdict)}
                  class="rounded border border-base-300"
                >
                  <div class="p-4 flex items-start justify-between gap-4">
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2 flex-wrap">
                        <span class={["badge badge-sm", verdict_badge_class(c.red_team_verdict)]}>
                          {verdict_label(c.red_team_verdict)}
                        </span>
                        <span class="font-medium">{c.label || "(unlabeled)"}</span>
                        <span class="text-xs text-base-content/60">score {c.score}</span>
                      </div>
                      <p
                        :if={c.red_team_verdict && c.red_team_verdict.kill_argument}
                        class="text-sm text-base-content/70 mt-2"
                      >
                        <strong>kill_argument:</strong> {c.red_team_verdict.kill_argument}
                      </p>
                      <button
                        type="button"
                        class="text-xs link link-hover mt-2"
                        phx-click="toggle_postings"
                        phx-value-candidate-id={c.id}
                        data-test="toggle-postings"
                      >
                        {if MapSet.member?(@expanded_candidates, c.id),
                          do: "▾ Hide postings",
                          else: "▸ Show #{posting_count(c)} postings"}
                      </button>
                    </div>
                    <button
                      class="btn btn-sm btn-error shrink-0"
                      phx-click="kill"
                      phx-value-candidate-id={c.id}
                      data-test="kill-button"
                    >
                      KILL
                    </button>
                  </div>
                  <.postings_list
                    :if={MapSet.member?(@expanded_candidates, c.id)}
                    candidate={c}
                  />
                </li>

                <li
                  :for={c <- Map.get(@board, :pending_candidates) || []}
                  data-test="board-row"
                  data-verdict="pending"
                  class="rounded border border-base-300 border-dashed opacity-80"
                >
                  <div class="p-4 flex items-start justify-between gap-4">
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2 flex-wrap">
                        <span class="badge badge-sm badge-ghost">PENDING RED-TEAM</span>
                        <span class="font-medium">{c.label || "(unlabeled)"}</span>
                        <span class="text-xs text-base-content/60">score {c.score}</span>
                      </div>
                      <p class="text-xs text-base-content/60 mt-2">
                        Money-gated by Score, awaiting prosecution. Use RedTeamCandidate (MCP) or KILL
                        below.
                      </p>
                      <button
                        type="button"
                        class="text-xs link link-hover mt-2"
                        phx-click="toggle_postings"
                        phx-value-candidate-id={c.id}
                        data-test="toggle-postings"
                      >
                        {if MapSet.member?(@expanded_candidates, c.id),
                          do: "▾ Hide postings",
                          else: "▸ Show #{posting_count(c)} postings"}
                      </button>
                    </div>
                    <button
                      class="btn btn-sm btn-error btn-outline shrink-0"
                      phx-click="kill"
                      phx-value-candidate-id={c.id}
                      data-test="kill-button"
                    >
                      KILL
                    </button>
                  </div>
                  <.postings_list
                    :if={MapSet.member?(@expanded_candidates, c.id)}
                    candidate={c}
                  />
                </li>
              </ul>
            <% end %>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :candidate, :map, required: true

  defp postings_list(assigns) do
    ~H"""
    <div class="border-t border-base-300 bg-base-200/40 px-4 py-3" data-test="postings-list">
      <ul class="divide-y divide-base-300">
        <li :for={p <- @candidate.job_postings} class="py-3" data-test="posting-row">
          <div class="flex items-baseline justify-between gap-3">
            <%= if p.url do %>
              <a
                href={p.url}
                target="_blank"
                rel="noopener"
                class="font-medium link link-hover truncate"
              >
                {p.title || "(untitled)"}
              </a>
            <% else %>
              <span class="font-medium truncate">{p.title || "(untitled)"}</span>
            <% end %>
            <span class="text-xs text-base-content/60 whitespace-nowrap shrink-0">
              {money_summary(p)}
            </span>
          </div>
          <p
            :if={p.pain_descriptor}
            class="text-xs text-base-content/70 mt-1 italic"
          >
            pain: {p.pain_descriptor}
          </p>
          <p
            :if={p.description}
            class="text-sm text-base-content/70 mt-1 line-clamp-3"
          >
            {p.description}
          </p>
        </li>
      </ul>
    </div>
    """
  end

  defp posting_count(%{job_postings: postings}) when is_list(postings), do: length(postings)
  defp posting_count(_), do: 0

  defp money_summary(p) do
    parts =
      [
        p.total_spent_cents && "$#{div(p.total_spent_cents, 100)} spent",
        p.hire_rate && "#{p.hire_rate}% hire rate"
      ]
      |> Enum.reject(&is_nil/1)

    case parts do
      [] -> ""
      _ -> Enum.join(parts, " • ")
    end
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

  # Verdict-priority ordering for the Board: best-news-first, so the
  # founder sees what's worth shipping before what's worth killing.
  # Within a verdict tier, higher score wins.
  @verdict_rank %{
    "keep_productizable" => 0,
    "keep_service_only" => 1,
    "watch" => 2,
    "kill" => 3
  }

  defp order_candidates(candidates) do
    Enum.sort_by(candidates, fn c ->
      v = verdict_attr(c.red_team_verdict)
      rank = Map.get(@verdict_rank, v, 99)
      # negate score so higher score sorts earlier within a rank
      {rank, -(c.score || 0)}
    end)
  end

  defp verdict_label(verdict_struct) do
    case verdict_attr(verdict_struct) do
      "keep_productizable" -> "KEEP — PRODUCTIZABLE"
      "keep_service_only" -> "KEEP — SERVICE ONLY"
      "watch" -> "WATCH"
      "kill" -> "KILL"
      _ -> "—"
    end
  end

  defp verdict_badge_class(verdict_struct) do
    case verdict_attr(verdict_struct) do
      "keep_productizable" -> "badge-success"
      "keep_service_only" -> "badge-warning"
      "watch" -> "badge-info"
      "kill" -> "badge-error"
      _ -> "badge-ghost"
    end
  end
end

##
## QA Story 738 — Polish Touchpoint: all 7 scenarios in a single BEAM boot.
##
## Run: VALE_STYLES_PATH=/path/to/styles MIX_ENV=dev mix run priv/repo/qa_738_scenarios.exs
##
## Uses only dev-env modules (no test fixtures). Creates isolated DB rows;
## rows persist in the dev database (harmless, namespaced by unique email).
##

alias MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint
alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
alias MarketMySpec.Linter
alias MarketMySpec.Users
alias MarketMySpec.Accounts
alias MarketMySpec.Users.Scope
alias MarketMySpec.Engagements.Thread
alias MarketMySpec.Engagements.Touchpoint
alias MarketMySpec.Repo
alias Anubis.Server.Response

# ---- Helpers ----

build_frame = fn scope ->
  %{
    assigns: %{current_scope: scope},
    context: %{session_id: "qa-738-#{System.unique_integer([:positive])}"}
  }
end

decode_payload = fn %Response{content: parts} when is_list(parts) ->
  parts
  |> Enum.map_join("\n", fn
    %{"text" => t} -> t
    %{text: t} -> t
    other -> inspect(other)
  end)
  |> Jason.decode!()
end

# Build an account-scoped user using only production modules
create_scope = fn label ->
  n = System.unique_integer([:positive])
  email = "qa738-#{label}-#{n}@qa.marketmyspec.test"

  {:ok, user} = Users.register_user(%{email: email})

  # Confirm user via internal token (mirrors what user_fixture does in test env)
  {encoded_token, user_token} = Users.UserToken.build_email_token(user, "login")
  Repo.insert!(user_token)
  {:ok, {confirmed_user, _}} = Users.login_user_by_magic_link(encoded_token)

  # Create default individual account
  {:ok, account} = Accounts.create_default_individual_account(confirmed_user)

  # Pin active_account_id
  {:ok, pinned_user} = Repo.update(Ecto.Changeset.change(confirmed_user, active_account_id: account.id))

  scope = Scope.for_user(pinned_user)
  IO.puts("Created #{label} scope: account=#{scope.active_account_id}")
  scope
end

thread_fixture = fn scope, extra_attrs ->
  n = System.unique_integer([:positive])
  source_thread_id = "qa-738-#{n}"

  attrs = Map.merge(%{
    account_id: scope.active_account_id,
    source: :reddit,
    source_thread_id: source_thread_id,
    url: "https://www.reddit.com/r/elixir/comments/#{source_thread_id}",
    title: "QA Thread #{source_thread_id}",
    op_body: nil,
    comment_tree: %{"children" => []},
    raw_payload: %{"source_thread_id" => source_thread_id},
    fetched_at: nil
  }, extra_attrs)

  %Thread{}
  |> Thread.changeset(attrs)
  |> Repo.insert!()
end

vale_ini_writegood = """
StylesPath = #{System.get_env("VALE_STYLES_PATH", "/app/priv/vale/styles")}
MinAlertLevel = warning

[*.md]
BasedOnStyles = write-good
"""

# ---- Build actors ----

IO.puts("=== Creating QA actors ===")
scope_sam = create_scope.("sam")
scope_bea = create_scope.("bea")
frame_sam = build_frame.(scope_sam)
frame_bea = build_frame.(scope_bea)

results = []

# ============================================================
# 6510: polish_touchpoint writes polished_body (no Vale config)
# ============================================================
IO.puts("\n--- 6510: writes polished_body (no config) ---")

thread_6510 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6510, _} = StageResponse.execute(
  %{thread_id: thread_6510.id, synopsis: "OP asks about something innocuous.", angle: "Point to community resources."},
  frame_sam
)
tp_id_6510 = decode_payload.(stage_resp_6510)["touchpoint_id"]

clean_body_6510 = "A measured reply that adds context without violating any voice rule."
{:reply, _polish_resp_6510, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6510, polished_body: clean_body_6510},
  frame_sam
)
{:reply, list_resp_6510, _} = ListTouchpoints.execute(%{thread_id: thread_6510.id}, frame_sam)
tps_6510 = decode_payload.(list_resp_6510)["touchpoints"] || []
tp_6510 = Enum.find(tps_6510, &(&1["id"] == tp_id_6510))
stored_6510 = tp_6510 && tp_6510["polished_body"]

result_6510 =
  if stored_6510 == clean_body_6510 do
    IO.puts("PASS 6510: polished_body persisted")
    %{name: "6510: writes polished_body (no config)", status: "pass",
      observation: "polished_body persisted verbatim after no-config lint returned empty alerts"}
  else
    IO.puts("FAIL 6510: got #{inspect(stored_6510)}")
    %{name: "6510: writes polished_body (no config)", status: "fail",
      observation: "expected #{inspect(clean_body_6510)}, got #{inspect(stored_6510)}"}
  end

results = [result_6510 | results]

# ============================================================
# 6513: No config returns empty alerts
# ============================================================
IO.puts("\n--- 6513: no config = empty alerts ---")

thread_6513 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6513, _} = StageResponse.execute(
  %{thread_id: thread_6513.id, synopsis: "OP asks for a recommendation.", angle: "Point to the obvious answer."},
  frame_sam
)
tp_id_6513 = decode_payload.(stage_resp_6513)["touchpoint_id"]

{:reply, polish_resp_6513, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6513, polished_body: "Some prose with very loose phrasing and weasel words."},
  frame_sam
)
payload_6513 = decode_payload.(polish_resp_6513)
alerts_6513 = payload_6513["alerts"]

result_6513 =
  if alerts_6513 == [] do
    IO.puts("PASS 6513: empty alerts when no config")
    %{name: "6513: no config returns empty alerts", status: "pass",
      observation: "alerts=[] when no Vale config saved on account"}
  else
    IO.puts("FAIL 6513: expected [], got #{inspect(alerts_6513)}")
    %{name: "6513: no config returns empty alerts", status: "fail",
      observation: "expected [], got #{inspect(alerts_6513)}"}
  end

results = [result_6513 | results]

# ============================================================
# Save write-good config for Sam (used by 6512, 6516, 6517, 6519)
# ============================================================
IO.puts("\n--- Saving write-good config for Sam ---")
save_result = Linter.save_config(scope_sam, vale_ini_writegood)
IO.puts("Save result: #{inspect(elem(save_result, 0))}")

# ============================================================
# 6512: Vale lints against account's saved configuration
# ============================================================
IO.puts("\n--- 6512: lints against saved config ---")

thread_6512 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6512, _} = StageResponse.execute(
  %{thread_id: thread_6512.id, synopsis: "OP asks for advice.", angle: "Suggest a measured response."},
  frame_sam
)
tp_id_6512 = decode_payload.(stage_resp_6512)["touchpoint_id"]

{:reply, polish_resp_6512, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6512, polished_body: "I think this is a very good idea overall."},
  frame_sam
)
payload_6512 = decode_payload.(polish_resp_6512)
alerts_6512 = payload_6512["alerts"] || []

has_writegood_alert = is_list(alerts_6512) and alerts_6512 != [] and
  Enum.any?(alerts_6512, fn a ->
    check = a["check"] || ""
    message = a["message"] || ""
    String.contains?(check, "write-good") or String.contains?(message, "very") or String.contains?(message, "weasel")
  end)

result_6512 =
  if has_writegood_alert do
    IO.puts("PASS 6512: write-good alert returned for weasel word 'very'")
    first = hd(alerts_6512)
    %{name: "6512: lints against saved config", status: "pass",
      observation: "write-good alert returned: check=#{first["check"]}, message=#{first["message"]}"}
  else
    IO.puts("FAIL 6512: expected write-good alert, got #{inspect(alerts_6512)}")
    %{name: "6512: lints against saved config", status: "fail",
      observation: "expected write-good alert for 'very', got #{inspect(alerts_6512)}"}
  end

results = [result_6512 | results]

# ============================================================
# 6515: Cross-account returns not_found and modifies nothing
# ============================================================
IO.puts("\n--- 6515: cross-account rejected ---")

thread_6515 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6515, _} = StageResponse.execute(
  %{thread_id: thread_6515.id, synopsis: "OP synopsis A.", angle: "Angle A."},
  frame_sam
)
tp_id_6515 = decode_payload.(stage_resp_6515)["touchpoint_id"]

# Bea tries to polish Sam's touchpoint
{:reply, cross_resp_6515, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6515, polished_body: "Attacker-attempted polished body."},
  frame_bea
)

is_error_6515 = Map.get(cross_resp_6515, :isError, false)

# Check Sam's touchpoint is unchanged
{:reply, list_a_6515, _} = ListTouchpoints.execute(%{thread_id: thread_6515.id}, frame_sam)
tps_a_6515 = decode_payload.(list_a_6515)["touchpoints"] || []
tp_a_6515 = Enum.find(tps_a_6515, &(&1["id"] == tp_id_6515))
polished_6515 = tp_a_6515 && tp_a_6515["polished_body"]

cross_content_json =
  cross_resp_6515
  |> Map.get(:content, [])
  |> Enum.map_join("", fn
    %{"text" => t} -> t
    %{text: t} -> t
    _ -> ""
  end)
no_leak = not String.contains?(cross_content_json, "Attacker-attempted polished body")

result_6515 =
  if is_error_6515 and polished_6515 == nil and no_leak do
    IO.puts("PASS 6515: cross-account rejected, body unchanged, no data leak")
    %{name: "6515: cross-account rejected, not_found", status: "pass",
      observation: "isError=true, Sam's polished_body still nil, no attacker prose in error response"}
  else
    IO.puts("FAIL 6515: is_error=#{is_error_6515}, polished=#{inspect(polished_6515)}, no_leak=#{no_leak}")
    %{name: "6515: cross-account rejected, not_found", status: "fail",
      observation: "is_error=#{is_error_6515}, polished=#{inspect(polished_6515)}, no_leak=#{no_leak}"}
  end

results = [result_6515 | results]

# ============================================================
# 6516: Alert objects are flat maps with severity/check/line/column/message
# ============================================================
IO.puts("\n--- 6516: flat alert shape ---")

thread_6516 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6516, _} = StageResponse.execute(
  %{thread_id: thread_6516.id, synopsis: "OP synopsis.", angle: "Angle."},
  frame_sam
)
tp_id_6516 = decode_payload.(stage_resp_6516)["touchpoint_id"]

{:reply, polish_resp_6516, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6516, polished_body: "This is very interesting and very useful."},
  frame_sam
)
payload_6516 = decode_payload.(polish_resp_6516)
alerts_6516 = payload_6516["alerts"] || []

shape_ok_6516 = is_list(alerts_6516) and alerts_6516 != [] and
  Enum.all?(alerts_6516, fn a ->
    is_map(a) and
    is_binary(a["severity"]) and
    is_binary(a["check"]) and
    is_integer(a["line"]) and
    is_integer(a["column"]) and
    is_binary(a["message"])
  end)

result_6516 =
  if shape_ok_6516 do
    IO.puts("PASS 6516: all #{length(alerts_6516)} alerts are flat maps with required fields")
    first = hd(alerts_6516)
    %{name: "6516: alerts are flat maps with required fields", status: "pass",
      observation: "#{length(alerts_6516)} alerts; first: severity=#{first["check"]}, check=#{first["check"]}, line=#{first["line"]}, col=#{first["column"]}"}
  else
    IO.puts("FAIL 6516: shape invalid. alerts=#{inspect(alerts_6516)}")
    %{name: "6516: alerts are flat maps with required fields", status: "fail",
      observation: "shape invalid: #{inspect(Enum.take(alerts_6516, 2))}"}
  end

results = [result_6516 | results]

# ============================================================
# 6517: Clean prose with config writes body, no alerts
# ============================================================
IO.puts("\n--- 6517: clean prose writes body, no alerts ---")

thread_6517 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6517, _} = StageResponse.execute(
  %{thread_id: thread_6517.id, synopsis: "OP synopsis.", angle: "Angle."},
  frame_sam
)
tp_id_6517 = decode_payload.(stage_resp_6517)["touchpoint_id"]

clean_body_6517 = "A short reply offering specific guidance without any flagged words."
{:reply, polish_resp_6517, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6517, polished_body: clean_body_6517},
  frame_sam
)

{:reply, list_resp_6517, _} = ListTouchpoints.execute(%{thread_id: thread_6517.id}, frame_sam)
tps_6517 = decode_payload.(list_resp_6517)["touchpoints"] || []
tp_6517 = Enum.find(tps_6517, &(&1["id"] == tp_id_6517))
stored_6517 = tp_6517 && tp_6517["polished_body"]
payload_6517 = decode_payload.(polish_resp_6517)
alerts_6517 = payload_6517["alerts"]

result_6517 =
  if alerts_6517 == [] and stored_6517 == clean_body_6517 do
    IO.puts("PASS 6517: clean prose writes body, no alerts")
    %{name: "6517: clean prose writes body, no alerts", status: "pass",
      observation: "alerts=[], polished_body persisted: #{inspect(stored_6517)}"}
  else
    IO.puts("FAIL 6517: alerts=#{inspect(alerts_6517)}, stored=#{inspect(stored_6517)}")
    %{name: "6517: clean prose writes body, no alerts", status: "fail",
      observation: "alerts=#{inspect(alerts_6517)}, stored=#{inspect(stored_6517)}"}
  end

results = [result_6517 | results]

# ============================================================
# 6519: Lint alerts block write; body unchanged
# ============================================================
IO.puts("\n--- 6519: lint blocks write ---")

thread_6519 = thread_fixture.(scope_sam, %{})

{:reply, stage_resp_6519, _} = StageResponse.execute(
  %{thread_id: thread_6519.id, synopsis: "OP synopsis.", angle: "Angle."},
  frame_sam
)
tp_id_6519 = decode_payload.(stage_resp_6519)["touchpoint_id"]

offending_body = "This is very useful and very interesting overall."
{:reply, polish_resp_6519, _} = PolishTouchpoint.execute(
  %{touchpoint_id: tp_id_6519, polished_body: offending_body},
  frame_sam
)

{:reply, list_resp_6519, _} = ListTouchpoints.execute(%{thread_id: thread_6519.id}, frame_sam)
tps_6519 = decode_payload.(list_resp_6519)["touchpoints"] || []
tp_6519 = Enum.find(tps_6519, &(&1["id"] == tp_id_6519))
stored_6519 = tp_6519 && tp_6519["polished_body"]
payload_6519 = decode_payload.(polish_resp_6519)
alerts_6519 = payload_6519["alerts"] || []

result_6519 =
  if alerts_6519 != [] and stored_6519 == nil do
    IO.puts("PASS 6519: #{length(alerts_6519)} alerts returned, write blocked, body still nil")
    %{name: "6519: lint alerts block write", status: "pass",
      observation: "#{length(alerts_6519)} alerts returned, polished_body still nil (write blocked)"}
  else
    IO.puts("FAIL 6519: alerts_count=#{length(alerts_6519)}, stored=#{inspect(stored_6519)}")
    %{name: "6519: lint alerts block write", status: "fail",
      observation: "alerts=#{inspect(alerts_6519)}, stored=#{inspect(stored_6519)}"}
  end

results = [result_6519 | results]

# ============================================================
# Summary
# ============================================================
IO.puts("\n========== SUMMARY ==========")
all_results = Enum.reverse(results)
Enum.each(all_results, fn r ->
  IO.puts("#{String.upcase(r.status)} | #{r.name}")
  IO.puts("     #{r.observation}")
end)

pass_count = Enum.count(all_results, &(&1.status == "pass"))
IO.puts("\nTotal: #{pass_count}/#{length(all_results)} passed")

if pass_count == length(all_results) do
  IO.puts("ALL PASS")
else
  IO.puts("SOME FAILED")
  System.stop(1)
end

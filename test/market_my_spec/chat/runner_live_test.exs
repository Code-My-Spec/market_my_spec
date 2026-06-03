defmodule MarketMySpec.Chat.RunnerLiveTest do
  @moduledoc """
  Live integration check for the Runner's real ReqLLM path against the actual
  Anthropic API.

  Excluded by default (`:live` tag). Run explicitly — it costs money and needs
  `ANTHROPIC_API_KEY` wired (config :req_llm, anthropic_api_key):

      mix test --only live test/market_my_spec/chat/runner_live_test.exs

  The deterministic spex (`test/spex/744_*`) cover orchestration via the
  `:chat_llm` fixture seam; this is the one place the *real* provider call is
  exercised, since ReqLLM's own fixtures ship only with its test suite and its
  streaming path bypasses req_cassette.
  """

  use MarketMySpecTest.DataCase, async: false

  import Ecto.Query

  alias MarketMySpec.Chat.{Conversation, Message, Runner}
  alias MarketMySpec.Repo

  @moduletag :live

  test "streams a real Anthropic reply and persists normalized metadata" do
    user = MarketMySpec.UsersFixtures.user_fixture()
    account = MarketMySpec.UsersFixtures.account_fixture(user)

    {:ok, conversation} =
      %Conversation{}
      |> Conversation.changeset(%{
        account_id: account.id,
        provider: :anthropic,
        model: "claude-sonnet-4-6"
      })
      |> Repo.insert()

    {:ok, _user} =
      %Message{}
      |> Message.changeset(%{
        conversation_id: conversation.id,
        role: :user,
        status: :complete,
        content: "Say hello in exactly three words."
      })
      |> Repo.insert()

    # Synchronous real call (no :chat_llm fixture set) — exercises real_stream.
    :ok = Runner.stream(conversation)

    assistant =
      Message
      |> where([m], m.conversation_id == ^conversation.id and m.role == :assistant)
      |> Repo.one!()

    assert assistant.status == :complete
    assert String.length(assistant.content) > 0
    assert assistant.input_tokens > 0
    assert assistant.output_tokens > 0
    assert assistant.finish_reason
    assert assistant.provider == :anthropic
    assert assistant.model == "claude-sonnet-4-6"
  end
end

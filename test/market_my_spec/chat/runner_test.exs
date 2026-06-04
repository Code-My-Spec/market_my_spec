defmodule MarketMySpec.Chat.RunnerTest do
  @moduledoc """
  Unit coverage for Runner internals that the fixture-driven spex cannot reach.

  The `:chat_llm` fixture stream ignores the conversation history entirely, so a
  malformed provider request never surfaces in the LiveView spex. `build_history/1`
  is the one place a multi-turn tool conversation can produce an invalid request,
  so it is exercised directly here.
  """

  use MarketMySpecTest.DataCase, async: true

  alias MarketMySpec.Chat.{Conversation, Message, Runner}
  alias MarketMySpec.Repo

  defp conversation_fixture(type \\ :marketing_strategy) do
    user = MarketMySpec.UsersFixtures.user_fixture()
    account = MarketMySpec.UsersFixtures.account_fixture(user)

    {:ok, conversation} =
      %Conversation{}
      |> Conversation.changeset(%{
        account_id: account.id,
        provider: :anthropic,
        model: "claude-sonnet-4-6",
        type: type
      })
      |> Repo.insert()

    conversation
  end

  defp insert_message!(conversation, attrs) do
    %Message{}
    |> Message.changeset(Map.put(attrs, :conversation_id, conversation.id))
    |> Repo.insert!()
  end

  describe "build_history/1" do
    test "excludes intermediate :tool rows so the next turn's request stays valid" do
      conversation = conversation_fixture()

      insert_message!(conversation, %{role: :user, status: :complete, content: "look at my board"})

      insert_message!(conversation, %{
        role: :tool,
        status: :complete,
        content: "frame: alpha",
        tool_name: "list_frames",
        tool_call_id: "call_abc123"
      })

      insert_message!(conversation, %{
        role: :assistant,
        status: :complete,
        content: "Your board has one frame, alpha."
      })

      history = Runner.build_history(conversation)

      # Regression: a :tool row leaking into the request has no tool_call_id and
      # the provider rejects it ("Tool message requires tool_call_id").
      refute Enum.any?(history, &(&1.role == :tool))

      assert history == [
               %{role: :user, content: "look at my board"},
               %{role: :assistant, content: "Your board has one frame, alpha."}
             ]
    end

    test "drops blank assistant turns (a pure tool-call reply with no text)" do
      conversation = conversation_fixture()

      insert_message!(conversation, %{role: :user, status: :complete, content: "do it"})
      insert_message!(conversation, %{role: :assistant, status: :complete, content: ""})

      assert Runner.build_history(conversation) == [%{role: :user, content: "do it"}]
    end

    test "ignores still-streaming messages" do
      conversation = conversation_fixture()

      insert_message!(conversation, %{role: :user, status: :complete, content: "hi"})
      insert_message!(conversation, %{role: :assistant, status: :streaming, content: "partial"})

      assert Runner.build_history(conversation) == [%{role: :user, content: "hi"}]
    end
  end

  describe "system_prompt/1" do
    test "marketing-strategy chats carry the SKILL.md playbook" do
      conversation = conversation_fixture(:marketing_strategy)
      {:ok, skill_md} = MarketMySpec.Skills.read_skill_md()

      prompt = Runner.system_prompt(conversation)

      assert is_binary(prompt)
      assert String.contains?(prompt, skill_md)
      # It instructs the model to start on its own, not wait for a tool.
      assert prompt =~ "begin the interview"
    end

    test "other chat types get no system prompt" do
      assert Runner.system_prompt(conversation_fixture(:problem_discovery)) == nil
      assert Runner.system_prompt(conversation_fixture(nil)) == nil
    end
  end
end

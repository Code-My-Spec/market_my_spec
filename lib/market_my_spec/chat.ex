defmodule MarketMySpec.Chat do
  @moduledoc """
  Public API for the conversational LLM chat context.

  Owns `Conversation` and `Message` entities and orchestrates streaming
  replies. The user message is persisted immediately on send (R1); the
  assistant reply is produced by `Runner` in a supervised task that streams
  over PubSub on `"chat:\#{conversation_id}"` (R2/R3). Provider and model are
  selectable per conversation and apply to the next message (R5).

  Surface for `MarketMySpecWeb.ChatLive.Index` (listing/creation) and
  `MarketMySpecWeb.ChatLive.Show` (a single conversation). Streaming,
  persistence, and the ReqLLM call live in `Runner`; reconnect state lives in
  `ActiveTasks`.
  """

  import Ecto.Query

  alias MarketMySpec.Chat.{Conversation, Message, Runner}
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  @default_provider :anthropic

  @doc "The default provider for a new conversation."
  @spec default_provider() :: Conversation.provider()
  def default_provider, do: @default_provider

  @doc "The default model for a provider."
  @spec default_model(Conversation.provider()) :: String.t()
  def default_model(provider \\ @default_provider)
  def default_model(:anthropic), do: "claude-sonnet-4-6"
  def default_model(:openai), do: "gpt-5-mini"

  @doc """
  Creates a new typed conversation (story 745). The chats index navigates
  straight into it. The `type` (problem_discovery | marketing_strategy)
  determines which tools the assistant may use.
  """
  @spec create_conversation(Scope.t(), Conversation.chat_type()) :: Conversation.t()
  def create_conversation(%Scope{active_account_id: account_id}, type) do
    {:ok, conversation} =
      %Conversation{}
      |> Conversation.changeset(%{
        account_id: account_id,
        provider: @default_provider,
        model: default_model(@default_provider),
        type: type
      })
      |> Repo.insert()

    conversation
  end

  @doc """
  Lists the account's conversations, most recently active first — the chats
  index/menu.
  """
  @spec list_conversations(Scope.t()) :: [Conversation.t()]
  def list_conversations(%Scope{active_account_id: account_id}) do
    Conversation
    |> where([c], c.account_id == ^account_id)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  @doc "Human label for a chat type."
  @spec type_label(Conversation.chat_type() | nil) :: String.t() | nil
  def type_label(:problem_discovery), do: "Problem Discovery"
  def type_label(:marketing_strategy), do: "Marketing Strategy"
  def type_label(_), do: nil

  @doc "Display label for a conversation in the chats index/menu."
  @spec conversation_label(Conversation.t()) :: String.t()
  def conversation_label(%Conversation{title: title}) when is_binary(title) and title != "",
    do: title

  def conversation_label(%Conversation{type: type}) when not is_nil(type),
    do: "New #{type_label(type)} chat"

  def conversation_label(_conversation), do: "New chat"

  @doc """
  Deletes a conversation and its messages within the caller's account scope.
  Returns `:ok` whether or not the conversation existed (idempotent).
  """
  @spec delete_conversation(Scope.t(), Ecto.UUID.t()) :: :ok
  def delete_conversation(%Scope{} = scope, id) do
    case get_conversation(scope, id) do
      nil ->
        :ok

      %Conversation{} = conversation ->
        Repo.delete_all(from m in Message, where: m.conversation_id == ^conversation.id)
        Repo.delete!(conversation)
        :ok
    end
  end

  @doc "Fetches a conversation by id within the caller's account scope."
  @spec get_conversation(Scope.t(), Ecto.UUID.t()) :: Conversation.t() | nil
  def get_conversation(%Scope{active_account_id: account_id}, id) do
    Conversation
    |> where([c], c.account_id == ^account_id and c.id == ^id)
    |> Repo.one()
  end

  @doc "Lists a conversation's messages in insertion order."
  @spec list_messages(Conversation.t()) :: [Message.t()]
  def list_messages(%Conversation{id: id}) do
    Message
    |> where([m], m.conversation_id == ^id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Persists a user message and kicks off a streaming assistant reply.

  Rejects empty/whitespace content (the changeset requires non-empty content
  for user messages, R1) — in that case no reply is started. On success the
  `Runner` streams the reply over PubSub.
  """
  @spec send_message(Conversation.t(), String.t()) ::
          {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def send_message(%Conversation{} = conversation, content) do
    with {:ok, message} <- persist_user_message(conversation, content) do
      maybe_set_title(conversation, message.content)
      Runner.run(conversation)
      {:ok, message}
    end
  end

  # Title an untitled conversation from its first message — gives the chats
  # menu a readable label. Done with update_all (not a changeset on the loaded
  # struct) and only when still untitled, so it stays a cheap, isolated write.
  defp maybe_set_title(%Conversation{id: id, title: nil}, content) do
    title = content |> String.slice(0, 60) |> String.trim()

    Conversation
    |> where([c], c.id == ^id and is_nil(c.title))
    |> Repo.update_all(set: [title: title])

    :ok
  end

  defp maybe_set_title(_conversation, _content), do: :ok

  @doc """
  Re-runs the assistant reply for the conversation's existing history. Used by
  the retry affordance after a recoverable stream error (R8).
  """
  @spec regenerate(Conversation.t()) :: {:ok, pid()} | {:error, term()}
  def regenerate(%Conversation{} = conversation), do: Runner.run(conversation)

  @doc """
  Changes the conversation's provider and model. Applies to the next message
  sent — existing messages are untouched (R5).
  """
  @spec update_model(Conversation.t(), Conversation.provider(), String.t()) ::
          {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()}
  def update_model(%Conversation{} = conversation, provider, model) do
    conversation
    |> Conversation.changeset(%{provider: provider, model: model})
    |> Repo.update()
  end

  # --- internals ---

  defp persist_user_message(conversation, content) do
    %Message{}
    |> Message.changeset(%{
      conversation_id: conversation.id,
      role: :user,
      status: :complete,
      content: normalize_content(content)
    })
    |> Repo.insert()
  end

  defp normalize_content(content) when is_binary(content), do: String.trim(content)
  defp normalize_content(_), do: ""
end

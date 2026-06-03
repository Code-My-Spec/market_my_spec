defmodule MarketMySpec.Chat do
  @moduledoc """
  Public API for the conversational LLM chat context.

  Owns `Conversation` and `Message` entities and orchestrates streaming
  replies. The user message is persisted immediately on send (R1); the
  assistant reply is produced by `Runner` in a supervised task that streams
  over PubSub on `"chat:\#{conversation_id}"` (R2/R3). Provider and model are
  selectable per conversation and apply to the next message (R5).

  Surface for `MarketMySpecWeb.ChatLive`. Streaming, persistence, and the
  ReqLLM call live in `Runner`; reconnect state lives in `ActiveTasks`.
  """

  import Ecto.Query

  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope
  alias MarketMySpec.Chat.{Conversation, Message, Runner}

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
  Returns the account's most recent conversation, creating a default one when
  none exists. This is the "active chat" the `/chat` surface mounts.
  """
  @spec get_or_create_active_conversation(Scope.t()) :: Conversation.t()
  def get_or_create_active_conversation(%Scope{active_account_id: account_id}) do
    case latest_conversation(account_id) do
      nil -> create_default_conversation(account_id)
      conversation -> conversation
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
      Runner.run(conversation)
      {:ok, message}
    end
  end

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

  defp latest_conversation(account_id) do
    Conversation
    |> where([c], c.account_id == ^account_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp create_default_conversation(account_id) do
    {:ok, conversation} =
      %Conversation{}
      |> Conversation.changeset(%{
        account_id: account_id,
        provider: @default_provider,
        model: default_model(@default_provider)
      })
      |> Repo.insert()

    conversation
  end

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

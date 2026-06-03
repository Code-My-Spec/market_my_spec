defmodule MarketMySpec.Chat.Conversation do
  @moduledoc """
  A chat conversation, scoped to an account (reusing the existing MMS
  auth/scope). Holds the provider and model selected for the conversation —
  both changeable, and applied to the *next* message sent (R5). Owns its
  Messages, ordered by insertion.

  The conversation `id` is the `chat_id` used in the PubSub topic
  `"chat:\#{chat_id}"` that the Runner broadcasts on and the LiveView
  subscribes to.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Chat.Message

  @type provider :: :anthropic | :openai

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          provider: provider(),
          model: String.t() | nil,
          title: String.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          messages: [Message.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "chat_conversations" do
    field :provider, Ecto.Enum, values: [:anthropic, :openai], default: :anthropic
    field :model, :string
    field :title, :string

    belongs_to :account, Account, type: :binary_id
    has_many :messages, Message, preload_order: [asc: :inserted_at]

    timestamps(type: :utc_datetime)
  end

  @required_fields [:account_id, :provider, :model]
  @optional_fields [:title]

  @doc """
  Changeset for creating or updating a Conversation.

  Required: account_id, provider, model. `provider` defaults to `:anthropic`;
  the caller supplies a concrete `model` (a default is resolved at creation
  time, not hard-coded into the schema). `title` is optional.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:model, min: 1, max: 255)
    |> validate_length(:title, max: 255)
    |> foreign_key_constraint(:account_id)
  end
end

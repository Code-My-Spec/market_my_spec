defmodule MarketMySpec.Chat.Message do
  @moduledoc """
  A single message in a Conversation.

  User messages persist immediately on send with `status: :complete` (R1).
  Assistant messages are created `:streaming`, accumulate content as chunks
  arrive, and finalize on `:stream_done` to `:complete` with normalized
  metadata (R6): provider, model, input/output tokens, cost, finish reason and
  response id. A failed reply finalizes to `:error` with an `error_reason`
  driving the recoverable error state (R8).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Chat.Conversation

  @type role :: :user | :assistant
  @type status :: :streaming | :complete | :error
  @type provider :: :anthropic | :openai

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          conversation_id: Ecto.UUID.t() | nil,
          role: role(),
          content: String.t(),
          status: status(),
          provider: provider() | nil,
          model: String.t() | nil,
          input_tokens: integer() | nil,
          output_tokens: integer() | nil,
          cost: Decimal.t() | nil,
          finish_reason: String.t() | nil,
          response_id: String.t() | nil,
          error_reason: String.t() | nil,
          conversation: Conversation.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "chat_messages" do
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :content, :string, default: ""
    field :status, Ecto.Enum, values: [:streaming, :complete, :error], default: :complete

    # Normalized reply metadata — populated on :stream_done (R6).
    field :provider, Ecto.Enum, values: [:anthropic, :openai]
    field :model, :string
    field :input_tokens, :integer
    field :output_tokens, :integer
    field :cost, :decimal
    field :finish_reason, :string
    field :response_id, :string
    field :error_reason, :string

    belongs_to :conversation, Conversation, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @metadata_fields [
    :provider,
    :model,
    :input_tokens,
    :output_tokens,
    :cost,
    :finish_reason,
    :response_id,
    :error_reason
  ]
  @cast_fields [:conversation_id, :role, :content, :status | @metadata_fields]

  @doc """
  Changeset for a message.

  Requires conversation_id and role. A user message must carry non-empty
  content; an assistant message may start empty (it fills as the stream
  arrives).
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(attrs, @cast_fields)
    |> validate_required([:conversation_id, :role, :status])
    |> validate_content_for_role()
    |> validate_number(:input_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:output_tokens, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:conversation_id)
  end

  defp validate_content_for_role(changeset) do
    case get_field(changeset, :role) do
      :user -> validate_required(changeset, [:content]) |> validate_length(:content, min: 1)
      _ -> changeset
    end
  end
end

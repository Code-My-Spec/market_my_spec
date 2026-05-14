defmodule MarketMySpec.Engagements.Touchpoint do
  @moduledoc """
  Saved post-back record for an engagement comment.

  Account-scoped. Records the final polished body that was posted,
  the live URL of the posted comment, the UTM-tracked destination
  embedded in the body, and the datetime when the comment was posted.

  Belongs to a Thread (the thread the comment was posted in reply to)
  and is scoped to an Account.

  ## Lifecycle

  A Touchpoint follows a two-state lifecycle:

  - **staged** — created by `stage_response` MCP tool with `polished_body` and
    `link_target` embedded. `comment_url` and `posted_at` are `nil`.
  - **posted** — transitioned when the user submits the live comment URL in the UI.
    `comment_url` and `posted_at` are populated.

  Use `staged_changeset/2` for staged creation and `changeset/2` for posted updates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Engagements.Thread

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: Ecto.UUID.t() | nil,
          thread_id: Ecto.UUID.t() | nil,
          comment_url: String.t() | nil,
          polished_body: String.t() | nil,
          link_target: String.t() | nil,
          posted_at: DateTime.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          thread: Thread.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "touchpoints" do
    field :comment_url, :string
    field :polished_body, :string
    field :link_target, :string
    field :posted_at, :utc_datetime

    belongs_to :account, Account, type: :binary_id
    belongs_to :thread, Thread, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a posted Touchpoint.

  Required: account_id, thread_id, comment_url, polished_body, posted_at.
  Optional: link_target (the bare URL embedded as a UTM link in polished_body).
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(touchpoint, attrs) do
    touchpoint
    |> cast(attrs, [:account_id, :thread_id, :comment_url, :polished_body, :link_target, :posted_at])
    |> validate_required([:account_id, :thread_id, :comment_url, :polished_body, :posted_at])
    |> validate_url(:comment_url)
    |> validate_url(:link_target)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:thread_id)
  end

  @doc """
  Changeset for creating a staged Touchpoint (no comment_url or posted_at yet).

  Required: account_id, thread_id, polished_body.
  Optional: link_target (the bare URL embedded as a UTM link in polished_body).

  Use this when the agent stages a draft via the stage_response MCP tool.
  The touchpoint transitions to posted via `changeset/2` when the user
  submits the live comment URL.
  """
  @spec staged_changeset(t(), map()) :: Ecto.Changeset.t()
  def staged_changeset(touchpoint, attrs) do
    touchpoint
    |> cast(attrs, [:account_id, :thread_id, :polished_body, :link_target])
    |> validate_required([:account_id, :thread_id, :polished_body])
    |> validate_url(:link_target)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:thread_id)
  end

  defp validate_url(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      url -> do_validate_url(changeset, field, url)
    end
  end

  defp do_validate_url(changeset, field, url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        changeset

      _ ->
        add_error(changeset, field, "must be a valid URL")
    end
  end
end

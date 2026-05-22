defmodule MarketMySpec.Engagements.Touchpoint do
  @moduledoc """
  Saved record of one comment the founder plans to post (or has posted)
  on a Thread.

  Account-scoped. Belongs to a Thread.

  ## Fields, by who writes them

  - `state`, `angle`, `utm_source`, `utm_medium`, `utm_campaign` —
    written at stage time by the `stage_response` MCP tool. UTM fields
    are derived from the parent Thread's source (Reddit ⇒ reddit/comment,
    ElixirForum ⇒ elixirforum/reply) and the `utm_campaign` defaults to
    `<subreddit>:<thread-name>` (or `<category-slug>:<thread-name>` for
    ElixirForum); the agent may override `utm_campaign` per call.

  - `polished_body` — written only by the `polish_touchpoint` MCP tool
    (story 738). The agent embeds whatever destination URL it picks
    with the UTM suffix appended (e.g.
    `https://codemyspec.com/blog/x?utm_source=reddit&utm_medium=comment&utm_campaign=elixir:abc123`)
    inside the prose body. The lint loop gates the write.

  - `comment_url`, `posted_at` — written only when the founder pastes
    the live URL of their actual posted comment back into the UI.
    `comment_url` is the URL of the comment on the source platform and
    is never UTM-tracked.

  - `link_target` — legacy column from the pre-707-redesign era; not
    populated by the new flow. Kept on the schema to avoid a destructive
    migration; revisit when there's a clear reason to drop it.

  ## Lifecycle

  - **staged** — `state: :staged`. Created by `stage_response`. May or
    may not have a `polished_body` yet (the polish loop runs after
    staging).
  - **posted** — `state: :posted`. Transitioned when the founder pastes
    the live `comment_url` and a `posted_at` timestamp.
  - **abandoned** — `state: :abandoned`. Non-destructive; angle,
    polished_body, and any prior comment_url are preserved.

  Use `staged_changeset/2` for stage-time creation, `update_changeset/2`
  for in-place transitions (the LiveView form and `update_touchpoint`
  MCP tool both use it), and `changeset/2` only for direct-to-posted
  creation paths (legacy).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Engagements.Thread

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          thread_id: Ecto.UUID.t() | nil,
          state: :staged | :posted | :abandoned | nil,
          angle: String.t() | nil,
          comment_url: String.t() | nil,
          polished_body: String.t() | nil,
          link_target: String.t() | nil,
          utm_source: String.t() | nil,
          utm_medium: String.t() | nil,
          utm_campaign: String.t() | nil,
          posted_at: DateTime.t() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          thread: Thread.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "touchpoints" do
    field :state, Ecto.Enum, values: [:staged, :posted, :abandoned]
    field :angle, :string
    field :comment_url, :string
    field :polished_body, :string
    field :link_target, :string
    field :utm_source, :string
    field :utm_medium, :string
    field :utm_campaign, :string
    field :posted_at, :utc_datetime

    belongs_to :account, Account, type: :binary_id
    belongs_to :thread, Thread, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a Touchpoint directly in the `:posted` state.

  Legacy path — present-day flow is `staged_changeset/2` at stage time
  followed by `update_changeset/2` once the founder marks it posted.

  Required: account_id, thread_id, comment_url, polished_body, posted_at.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(touchpoint, attrs) do
    touchpoint
    |> cast(attrs, [
      :account_id,
      :thread_id,
      :state,
      :angle,
      :comment_url,
      :polished_body,
      :link_target,
      :utm_source,
      :utm_medium,
      :utm_campaign,
      :posted_at
    ])
    |> put_default_state_from_posted_at()
    |> validate_required([:account_id, :thread_id, :comment_url, :polished_body, :posted_at])
    |> validate_url(:comment_url)
    |> validate_url(:link_target)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:thread_id)
  end

  # If no explicit state is set, derive it: :posted when posted_at present, else :staged.
  defp put_default_state_from_posted_at(changeset) do
    case get_field(changeset, :state) do
      nil ->
        if get_field(changeset, :posted_at) do
          put_change(changeset, :state, :posted)
        else
          put_change(changeset, :state, :staged)
        end

      _state ->
        changeset
    end
  end

  @doc """
  Changeset for creating a staged Touchpoint.

  Required: account_id, thread_id. State defaults to `:staged`.

  Optional at stage time: `angle`, `utm_source`, `utm_medium`,
  `utm_campaign`, and `polished_body`. In the new (post-707) flow,
  `stage_response` writes angle + the three UTM columns; the body
  fills in later via the `polish_touchpoint` MCP tool (story 738).

  `comment_url` and `posted_at` are never written here — they're set
  later via `update_changeset/2` when the founder pastes the live URL.
  """
  @spec staged_changeset(t(), map()) :: Ecto.Changeset.t()
  def staged_changeset(touchpoint, attrs) do
    touchpoint
    |> cast(attrs, [
      :account_id,
      :thread_id,
      :state,
      :angle,
      :polished_body,
      :link_target,
      :utm_source,
      :utm_medium,
      :utm_campaign
    ])
    |> put_default_state(:staged)
    |> validate_required([:account_id, :thread_id])
    |> validate_url(:link_target)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:thread_id)
  end

  defp put_default_state(changeset, default) do
    case get_field(changeset, :state) do
      nil -> put_change(changeset, :state, default)
      _state -> changeset
    end
  end

  @doc """
  Changeset for editing an existing Touchpoint — state transitions plus
  any non-body field edits.

  Allowed transitions: any state → :staged | :posted | :abandoned.
  Transitioning to :posted requires comment_url and posted_at.
  Transitioning to :staged or :abandoned does not.

  Used by the `update_touchpoint` MCP tool and the TouchpointLive.Show
  edit form. Note: in the post-707 flow, `polished_body` writes route
  through `polish_touchpoint` (story 738) — the MCP tool schema for
  `update_touchpoint` no longer exposes that field, but the changeset
  still casts it so the LiveView edit form (which writes directly via
  this changeset) keeps working.
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(touchpoint, attrs) do
    changeset =
      touchpoint
      |> cast(attrs, [:state, :comment_url, :posted_at, :polished_body, :angle])
      |> cast(attrs, [:utm_source, :utm_medium, :utm_campaign])

    state = get_field(changeset, :state)

    if state == :posted do
      changeset
      |> validate_required([:state, :comment_url, :posted_at])
      |> validate_url(:comment_url)
    else
      changeset
      |> validate_required([:state])
    end
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

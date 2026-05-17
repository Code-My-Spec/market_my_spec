defmodule MarketMySpec.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t(),
          slug: String.t() | nil,
          subdomain: String.t() | nil,
          logo_url: String.t() | nil,
          primary_color: String.t() | nil,
          secondary_color: String.t() | nil,
          google_analytics_property_id: String.t() | nil,
          type: atom(),
          role: atom() | nil,
          members: [MarketMySpec.Accounts.Member.t()] | Ecto.Association.NotLoaded.t(),
          users: [MarketMySpec.Users.User.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @reserved_slugs ~w(admin api www help support docs blog)
  @hex_color_format ~r/^#[0-9a-fA-F]{6}$/


  @primary_key {:id, :binary_id, autogenerate: true}
  schema "accounts" do
    field :name, :string
    field :slug, :string
    field :subdomain, :string
    field :logo_url, :string
    field :primary_color, :string
    field :secondary_color, :string
    field :google_analytics_property_id, :string
    field :type, Ecto.Enum, values: [:individual, :agency], default: :individual
    field :role, Ecto.Enum, values: [:owner, :admin, :member], virtual: true

    has_many :members, MarketMySpec.Accounts.Member, on_delete: :delete_all
    has_many :users, through: [:members, :user]

    timestamps()
  end

  @doc """
  Changeset for setting an agency account's branding — logo URL, primary
  color, secondary color. Validates HTTPS URL format and #rrggbb color
  format. All fields are optional individually; agencies render the
  default theme when fields are blank.
  """
  def branding_changeset(account, attrs) do
    account
    |> cast(attrs, [:logo_url, :primary_color, :secondary_color])
    |> validate_logo_url()
    |> validate_color(:primary_color)
    |> validate_color(:secondary_color)
  end

  defp validate_logo_url(changeset) do
    case get_field(changeset, :logo_url) do
      nil -> changeset
      "" -> changeset
      url -> validate_https_url(changeset, url)
    end
  end

  defp validate_https_url(changeset, url) do
    case URI.new(url) do
      {:ok, %URI{scheme: "https", host: host}} when is_binary(host) and host != "" ->
        changeset

      {:ok, %URI{scheme: "http"}} ->
        add_error(changeset, :logo_url, "must be HTTPS")

      _ ->
        add_error(changeset, :logo_url, "must be a valid URL")
    end
  end

  defp validate_color(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      _ -> validate_format(changeset, field, @hex_color_format,
             message: "must be a valid hex color in the form #rrggbb"
           )
    end
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_slug()
    |> unique_constraint(:slug, message: "already taken")
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> maybe_generate_slug()
  end

  def admin_changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :slug, :type, :google_analytics_property_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:type, [:individual, :agency])
    |> validate_slug()
    |> unique_constraint(:slug, message: "already taken")
  end

  @doc """
  Changeset for setting the Google Analytics 4 property ID used by the
  AnalyticsAdmin MCP tools. Property IDs are bare numeric strings (e.g.
  "123456789"); tools prepend the "properties/" prefix when calling the
  API. Empty strings are normalized to nil.
  """
  def analytics_changeset(account, attrs) do
    account
    |> cast(attrs, [:google_analytics_property_id])
    |> update_change(:google_analytics_property_id, &normalize_property_id/1)
    |> validate_format(:google_analytics_property_id, ~r/^\d+$/,
      message: "must be a numeric GA4 property ID (digits only)"
    )
  end

  defp normalize_property_id(nil), do: nil
  defp normalize_property_id(""), do: nil
  defp normalize_property_id(value) when is_binary(value), do: String.trim(value)

  @doc """
  Changeset for setting or changing an agency account's subdomain.

  Only agency-typed accounts may claim a subdomain. The subdomain must be
  3-50 chars, lowercase alphanumeric with hyphens, must start with a letter,
  must not be a reserved name, and must be globally unique among agencies.
  """
  def subdomain_changeset(account, attrs) do
    account
    |> cast(attrs, [:subdomain])
    |> validate_required([:subdomain])
    |> validate_agency_type()
    |> validate_subdomain()
    |> unique_constraint(:subdomain,
      name: :accounts_subdomain_index,
      message: "is already taken"
    )
  end

  defp validate_agency_type(changeset) do
    case get_field(changeset, :type) do
      :agency -> changeset
      _ -> add_error(changeset, :subdomain, "is only available for agency accounts")
    end
  end

  defp validate_subdomain(changeset) do
    changeset
    |> validate_format(:subdomain, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:subdomain, min: 3, max: 50)
    |> validate_exclusion(:subdomain, @reserved_slugs,
      message: "is reserved and cannot be used"
    )
    |> validate_format(:subdomain, ~r/^[a-z]/, message: "must start with a letter")
  end

  defp validate_slug(changeset) do
    changeset
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_exclusion(:slug, @reserved_slugs, message: "is reserved and cannot be used")
    |> validate_format(:slug, ~r/^[a-z]/, message: "must start with a letter")
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_field(changeset, :name)
        if name, do: put_change(changeset, :slug, generate_slug(name)), else: changeset

      _ ->
        changeset
    end
  end

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end

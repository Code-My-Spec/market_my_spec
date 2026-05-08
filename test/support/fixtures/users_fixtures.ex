defmodule MarketMySpec.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MarketMySpec.Users` context.
  """

  import Ecto.Query

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.AccountsRepository
  alias MarketMySpec.Accounts.MembersRepository
  alias MarketMySpec.Agencies.AgenciesRepository
  alias MarketMySpec.Users
  alias MarketMySpec.Users.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Users.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    skip_default_account = Map.get(attrs, :skip_default_account, false)
    attrs = Map.delete(attrs, :skip_default_account)

    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Users.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Users.login_user_by_magic_link(token)

    user =
      if skip_default_account do
        user
      else
        {:ok, account} = Accounts.create_default_individual_account(user)
        # Pin active_account_id so Scope.for_user/1 is deterministic when
        # tests create additional accounts after the default. Without this,
        # scope.active_account_id falls back to "newest by inserted_at",
        # which ties on the same DB tick and flakes test isolation.
        {:ok, user} = MarketMySpec.Repo.update(
          Ecto.Changeset.change(user, active_account_id: account.id)
        )
        user
      end

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  @doc """
  Creates an admin-provisioned agency account owned by the given user.
  This simulates the admin provisioning flow where the account type is set
  to `:agency` directly, bypassing the self-service form which only creates
  individual accounts.
  """
  def agency_account_fixture(user) do
    unique_suffix = System.unique_integer([:positive])
    attrs = %{name: "Agency Account #{unique_suffix}", type: :agency}

    case AccountsRepository.create_agency_account_with_owner(attrs, user.id) do
      {:ok, account} -> account
      {:error, reason} -> raise "Failed to create agency account fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates an individual account owned by the given user.
  Accepts optional attrs to override defaults (e.g., %{name: "My Co"}).
  """
  def account_fixture(user, attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])
    default_attrs = %{name: "Account #{unique_suffix}"}
    merged_attrs = Map.merge(default_attrs, attrs)

    case AccountsRepository.create_account_with_owner(merged_attrs, user.id) do
      {:ok, account} -> account
      {:error, reason} -> raise "Failed to create account fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates an invited agency-client grant (originator="client", status="accepted").
  Used when a client has granted an agency access to their account.
  Accepts keyword list or map for attrs (e.g., access_level: "account_manager").
  """
  def invited_grant_fixture(agency_account, client_account, attrs \\ []) do
    attrs_map = Enum.into(attrs, %{})
    access_level = Map.get(attrs_map, :access_level, "read_only")

    case AgenciesRepository.create_invited_grant(%{
           agency_account_id: agency_account.id,
           client_account_id: client_account.id,
           access_level: access_level
         }) do
      {:ok, grant} -> grant
      {:error, reason} -> raise "Failed to create invited grant fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a new client account and an agency-originated grant in one shot.
  Used to set up "agency created this client" scenarios.
  Returns {client_account, grant}.
  """
  def originated_client_fixture(agency_account, attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])
    default_attrs = %{name: "Client #{unique_suffix}"}
    client_attrs = Map.merge(default_attrs, attrs)

    # Create an anonymous user to own the client account, or we can skip that
    # and just create the account without an owner (use the agency owner).
    # For fixture purposes we create an ownerless account via a throwaway user.
    throwaway_user = user_fixture(%{skip_default_account: true})

    case AccountsRepository.create_account_with_owner(client_attrs, throwaway_user.id) do
      {:ok, client_account} ->
        grant_attrs = %{
          agency_account_id: agency_account.id,
          client_account_id: client_account.id,
          access_level: "account_manager"
        }

        case AgenciesRepository.create_originated_grant(grant_attrs) do
          {:ok, grant} -> {client_account, grant}
          {:error, reason} -> raise "Failed to create originated grant fixture: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Failed to create client account in originated_client_fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Adds a user as a member of an account with the given role.
  Accepts role as atom or string.
  """
  def account_member_fixture(account, user, opts \\ []) do
    opts_map = Enum.into(opts, %{})
    role = Map.get(opts_map, :role, "member")
    role_atom = if is_atom(role), do: role, else: String.to_existing_atom(role)

    case MembersRepository.add_user_to_account(user.id, account.id, role_atom) do
      {:ok, member} -> member
      {:error, reason} -> raise "Failed to create account member fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a registered user with a confirmed account scope.
  Used by spex tests that need a user with an active account context.
  """
  def account_scoped_user_fixture do
    user = user_fixture()
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Users.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    MarketMySpec.Repo.update_all(
      from(t in Users.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Users.UserToken.build_email_token(user, "login")
    MarketMySpec.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    MarketMySpec.Repo.update_all(
      from(ut in Users.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end

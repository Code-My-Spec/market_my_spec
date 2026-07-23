defmodule MarketMySpecSpex.Story695.Criterion6005Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6005 — Individual account attempts to claim a subdomain

  Story rule: only agency-typed accounts can claim a subdomain.
  Individual-typed accounts must not be able to set a subdomain.

  This may not have a clickable repro — the settings UI may not even
  expose the form to individual accounts. The defensive check still
  exists at the model layer (changeset rejection).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts.Account
  alias MarketMySpecSpex.Fixtures

  spex "individual account attempts to claim a subdomain" do
    scenario "the subdomain changeset rejects an individual-typed account" do
      given_ "an individual-typed account 'Sam's Solo'", context do
        sam = Fixtures.user_fixture()
        individual = Fixtures.account_fixture(sam, %{name: "Sam's Solo"})

        {:ok, Map.merge(context, %{sam: sam, individual: individual})}
      end

      when_ "the subdomain changeset is invoked on the individual account", context do
        changeset = Account.subdomain_changeset(context.individual, %{subdomain: "sam"})
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with a 'agency-only' error on subdomain", context do
        refute context.changeset.valid?,
               "expected subdomain changeset to be invalid for an individual account"

        errors = errors_on_changeset(context.changeset)

        assert Enum.any?(errors[:subdomain] || [], &(&1 =~ ~r/agency/i)),
               "expected an 'agency-only' error message on :subdomain, got: #{inspect(errors)}"

        {:ok, context}
      end
    end
  end

  defp errors_on_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

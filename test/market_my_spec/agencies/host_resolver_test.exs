defmodule MarketMySpec.Agencies.HostResolverTest do
  use MarketMySpecTest.DataCase, async: true

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpec.UsersFixtures

  describe "resolve_host/1" do
    test "returns the agency for a claimed subdomain on the apex" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)
      {:ok, agency} = HostResolver.claim_subdomain(agency, "acme")

      assert {:ok, resolved} = HostResolver.resolve_host("acme.marketmyspec.com")
      assert resolved.id == agency.id
      assert resolved.subdomain == "acme"
      assert resolved.type == :agency
    end

    test "case-insensitive: uppercase host still resolves" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)
      {:ok, _} = HostResolver.claim_subdomain(agency, "acme")

      assert {:ok, _} = HostResolver.resolve_host("ACME.MarketMySpec.com")
    end

    test "returns :none for the apex itself" do
      assert HostResolver.resolve_host("marketmyspec.com") == :none
    end

    test "returns :none for a never-claimed subdomain" do
      assert HostResolver.resolve_host("ghost.marketmyspec.com") == :none
    end

    test "returns :none for a previously-claimed subdomain after rename" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)
      {:ok, agency} = HostResolver.claim_subdomain(agency, "acme")
      {:ok, _} = HostResolver.claim_subdomain(agency, "acme-co")

      assert HostResolver.resolve_host("acme.marketmyspec.com") == :none
      assert {:ok, _} = HostResolver.resolve_host("acme-co.marketmyspec.com")
    end

    test "returns :none for hosts on a different domain" do
      assert HostResolver.resolve_host("acme.example.com") == :none
    end
  end

  describe "claim_subdomain/2" do
    test "rejects subdomain claims on individual-typed accounts" do
      user = UsersFixtures.user_fixture()
      individual = UsersFixtures.account_fixture(user)

      assert {:error, changeset} = HostResolver.claim_subdomain(individual, "acme")
      assert "is only available for agency accounts" in errors_on(changeset).subdomain
    end

    test "rejects malformed subdomain (uppercase / special chars)" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)

      assert {:error, _} = HostResolver.claim_subdomain(agency, "Acme!")
    end

    test "rejects reserved subdomains" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)

      for reserved <- ~w(admin api www help support docs blog) do
        assert {:error, changeset} = HostResolver.claim_subdomain(agency, reserved)
        assert "is reserved and cannot be used" in errors_on(changeset).subdomain
      end
    end

    test "rejects subdomains under 3 characters" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)

      assert {:error, _} = HostResolver.claim_subdomain(agency, "ac")
    end

    test "rejects subdomains starting with a digit" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)

      assert {:error, changeset} = HostResolver.claim_subdomain(agency, "1acme")
      assert "must start with a letter" in errors_on(changeset).subdomain
    end

    test "rejects a subdomain already taken by another agency" do
      user_a = UsersFixtures.user_fixture()
      user_b = UsersFixtures.user_fixture()
      agency_a = UsersFixtures.agency_account_fixture(user_a)
      agency_b = UsersFixtures.agency_account_fixture(user_b)

      {:ok, _} = HostResolver.claim_subdomain(agency_a, "acme")
      assert {:error, changeset} = HostResolver.claim_subdomain(agency_b, "acme")
      assert "is already taken" in errors_on(changeset).subdomain
    end

    test "an agency can change its subdomain" do
      user = UsersFixtures.user_fixture()
      agency = UsersFixtures.agency_account_fixture(user)
      {:ok, agency} = HostResolver.claim_subdomain(agency, "acme")

      assert {:ok, updated} = HostResolver.claim_subdomain(agency, "acme-co")
      assert updated.subdomain == "acme-co"
    end
  end
end

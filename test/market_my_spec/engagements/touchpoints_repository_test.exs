defmodule MarketMySpec.Engagements.TouchpointsRepositoryTest do
  use MarketMySpecTest.DataCase, async: true

  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.Engagements.TouchpointsRepository
  alias MarketMySpec.Repo
  alias MarketMySpec.UsersFixtures

  defp user_fixture, do: UsersFixtures.user_fixture()
  defp account_fixture(user), do: UsersFixtures.account_fixture(user)
  defp scope_fixture(user), do: UsersFixtures.user_scope_fixture(user)

  defp thread_fixture(account_id) do
    attrs = %{
      account_id: account_id,
      source: :reddit,
      source_thread_id: "thread_#{System.unique_integer([:positive])}",
      url: "https://reddit.com/r/elixir/comments/test/",
      title: "Test thread",
      fetched_at: DateTime.utc_now(:second)
    }

    %Thread{}
    |> Thread.changeset(attrs)
    |> Repo.insert!()
  end

  defp valid_touchpoint_attrs(account_id, thread_id) do
    %{
      account_id: account_id,
      thread_id: thread_id,
      comment_url: "https://reddit.com/r/elixir/comments/test/comment/abc123/",
      polished_body: "Great question! CodeMySpec handles the full lifecycle.",
      link_target: "https://codemyspec.com/?utm_source=reddit",
      posted_at: DateTime.utc_now(:second)
    }
  end

  describe "create_touchpoint/2" do
    test "creates a touchpoint scoped to the active account" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      attrs = %{
        thread_id: thread.id,
        comment_url: "https://reddit.com/r/elixir/comments/test/comment/abc123/",
        polished_body: "Great question! CodeMySpec handles the full lifecycle.",
        posted_at: DateTime.utc_now(:second)
      }

      assert {:ok, touchpoint} = TouchpointsRepository.create_touchpoint(scope, attrs)
      assert touchpoint.account_id == scope.active_account_id
      assert touchpoint.thread_id == thread.id
      assert touchpoint.comment_url == attrs.comment_url
      assert touchpoint.polished_body == attrs.polished_body
    end

    test "overrides account_id in attrs with scope's active_account_id" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      other_user = user_fixture()
      other_account = account_fixture(other_user)

      attrs = %{
        account_id: other_account.id,
        thread_id: thread.id,
        comment_url: "https://reddit.com/r/elixir/comments/test/comment/abc123/",
        polished_body: "Great question!",
        posted_at: DateTime.utc_now(:second)
      }

      assert {:ok, touchpoint} = TouchpointsRepository.create_touchpoint(scope, attrs)
      assert touchpoint.account_id == scope.active_account_id
      refute touchpoint.account_id == other_account.id
    end

    test "stores optional link_target" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      attrs = %{
        thread_id: thread.id,
        comment_url: "https://reddit.com/r/elixir/comments/test/comment/abc123/",
        polished_body: "Great question!",
        link_target: "https://codemyspec.com/?utm_source=reddit",
        posted_at: DateTime.utc_now(:second)
      }

      assert {:ok, touchpoint} = TouchpointsRepository.create_touchpoint(scope, attrs)
      assert touchpoint.link_target == attrs.link_target
    end

    test "returns error changeset when required fields are missing" do
      user = user_fixture()
      _account = account_fixture(user)
      scope = scope_fixture(user)

      assert {:error, changeset} = TouchpointsRepository.create_touchpoint(scope, %{})
      assert errors_on(changeset).thread_id
      assert errors_on(changeset).comment_url
      assert errors_on(changeset).polished_body
      assert errors_on(changeset).posted_at
    end

    test "returns error changeset when comment_url is not a valid URL" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      attrs = %{
        thread_id: thread.id,
        comment_url: "not-a-url",
        polished_body: "Great question!",
        posted_at: DateTime.utc_now(:second)
      }

      assert {:error, changeset} = TouchpointsRepository.create_touchpoint(scope, attrs)
      assert "must be a valid URL" in errors_on(changeset).comment_url
    end
  end

  describe "list_touchpoints/1" do
    test "returns all touchpoints for the scoped account" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      attrs = valid_touchpoint_attrs(account.id, thread.id)
      {:ok, touchpoint1} = TouchpointsRepository.create_touchpoint(scope, attrs)
      {:ok, touchpoint2} = TouchpointsRepository.create_touchpoint(scope, attrs)

      results = TouchpointsRepository.list_touchpoints(scope)
      ids = Enum.map(results, & &1.id)

      assert touchpoint1.id in ids
      assert touchpoint2.id in ids
    end

    test "does not return touchpoints from other accounts" do
      user_a = user_fixture()
      account_a = account_fixture(user_a)
      scope_a = scope_fixture(user_a)
      thread_a = thread_fixture(account_a.id)

      user_b = user_fixture()
      account_b = account_fixture(user_b)
      scope_b = scope_fixture(user_b)
      thread_b = thread_fixture(account_b.id)

      attrs_a = valid_touchpoint_attrs(account_a.id, thread_a.id)
      attrs_b = valid_touchpoint_attrs(account_b.id, thread_b.id)

      {:ok, tp_a} = TouchpointsRepository.create_touchpoint(scope_a, attrs_a)
      {:ok, tp_b} = TouchpointsRepository.create_touchpoint(scope_b, attrs_b)

      results_a = TouchpointsRepository.list_touchpoints(scope_a)
      ids_a = Enum.map(results_a, & &1.id)

      assert tp_a.id in ids_a
      refute tp_b.id in ids_a
    end

    test "returns results ordered by posted_at descending" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      earlier = DateTime.utc_now(:second) |> DateTime.add(-3600, :second)
      later = DateTime.utc_now(:second)

      attrs_earlier =
        account.id
        |> valid_touchpoint_attrs(thread.id)
        |> Map.put(:posted_at, earlier)

      attrs_later =
        account.id
        |> valid_touchpoint_attrs(thread.id)
        |> Map.put(:posted_at, later)

      {:ok, tp_earlier} = TouchpointsRepository.create_touchpoint(scope, attrs_earlier)
      {:ok, tp_later} = TouchpointsRepository.create_touchpoint(scope, attrs_later)

      [first | _] = TouchpointsRepository.list_touchpoints(scope)
      assert first.id == tp_later.id
      assert tp_earlier.id != first.id
    end

    test "returns empty list when account has no touchpoints" do
      user = user_fixture()
      _account = account_fixture(user)
      scope = scope_fixture(user)

      assert [] == TouchpointsRepository.list_touchpoints(scope)
    end
  end

  describe "list_touchpoints_for_thread/2" do
    test "returns only touchpoints for the given thread" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread_a = thread_fixture(account.id)
      thread_b = thread_fixture(account.id)

      attrs_a = valid_touchpoint_attrs(account.id, thread_a.id)
      attrs_b = valid_touchpoint_attrs(account.id, thread_b.id)

      {:ok, tp_a} = TouchpointsRepository.create_touchpoint(scope, attrs_a)
      {:ok, tp_b} = TouchpointsRepository.create_touchpoint(scope, attrs_b)

      results = TouchpointsRepository.list_touchpoints_for_thread(scope, thread_a.id)
      ids = Enum.map(results, & &1.id)

      assert tp_a.id in ids
      refute tp_b.id in ids
    end

    test "does not return touchpoints from other accounts even for same thread id" do
      user_a = user_fixture()
      account_a = account_fixture(user_a)
      scope_a = scope_fixture(user_a)
      thread_a = thread_fixture(account_a.id)

      user_b = user_fixture()
      account_b = account_fixture(user_b)
      scope_b = scope_fixture(user_b)
      thread_b = thread_fixture(account_b.id)

      attrs_a = valid_touchpoint_attrs(account_a.id, thread_a.id)
      attrs_b = valid_touchpoint_attrs(account_b.id, thread_b.id)

      {:ok, tp_a} = TouchpointsRepository.create_touchpoint(scope_a, attrs_a)
      {:ok, _tp_b} = TouchpointsRepository.create_touchpoint(scope_b, attrs_b)

      # scope_b cannot see thread_a's touchpoints
      results = TouchpointsRepository.list_touchpoints_for_thread(scope_b, thread_a.id)
      ids = Enum.map(results, & &1.id)

      refute tp_a.id in ids
      assert ids == []
    end

    test "returns empty list when no touchpoints exist for the thread" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      assert [] == TouchpointsRepository.list_touchpoints_for_thread(scope, thread.id)
    end

    test "returns multiple touchpoints for the same thread ordered by posted_at descending" do
      user = user_fixture()
      account = account_fixture(user)
      scope = scope_fixture(user)
      thread = thread_fixture(account.id)

      earlier = DateTime.utc_now(:second) |> DateTime.add(-3600, :second)
      later = DateTime.utc_now(:second)

      attrs_earlier =
        account.id
        |> valid_touchpoint_attrs(thread.id)
        |> Map.put(:posted_at, earlier)

      attrs_later =
        account.id
        |> valid_touchpoint_attrs(thread.id)
        |> Map.put(:posted_at, later)

      {:ok, tp_earlier} = TouchpointsRepository.create_touchpoint(scope, attrs_earlier)
      {:ok, tp_later} = TouchpointsRepository.create_touchpoint(scope, attrs_later)

      [first | _] = TouchpointsRepository.list_touchpoints_for_thread(scope, thread.id)
      assert first.id == tp_later.id
      assert tp_earlier.id != first.id
    end
  end
end

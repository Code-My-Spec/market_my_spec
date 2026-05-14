defmodule MarketMySpec.Engagements.ThreadTest do
  use MarketMySpecTest.DataCase, async: true

  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.UsersFixtures

  @valid_attrs %{
    source: :reddit,
    source_thread_id: "abc123",
    url: "https://www.reddit.com/r/elixir/comments/abc123/",
    title: "How do you structure Phoenix contexts?",
    op_body: "I've been wondering about best practices for context boundaries...",
    comment_tree: %{"comments" => []},
    raw_payload: %{"data" => %{"id" => "abc123"}},
    fetched_at: DateTime.utc_now(:second)
  }

  defp account_fixture do
    user = UsersFixtures.user_fixture()
    UsersFixtures.account_fixture(user)
  end

  describe "changeset/2" do
    test "valid attrs produce a valid changeset" do
      account = account_fixture()
      attrs = Map.put(@valid_attrs, :account_id, account.id)

      changeset = Thread.changeset(%Thread{}, attrs)
      assert changeset.valid?
    end

    test "requires account_id" do
      changeset = Thread.changeset(%Thread{}, @valid_attrs)
      assert "can't be blank" in errors_on(changeset).account_id
    end

    test "requires source" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:source)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert "can't be blank" in errors_on(changeset).source
    end

    test "requires source_thread_id" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:source_thread_id)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert "can't be blank" in errors_on(changeset).source_thread_id
    end

    test "requires url" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:url)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert "can't be blank" in errors_on(changeset).url
    end

    test "requires title" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:title)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "requires fetched_at" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:fetched_at)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert "can't be blank" in errors_on(changeset).fetched_at
    end

    test "op_body is optional" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:op_body)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert changeset.valid?
    end

    test "comment_tree defaults to empty map" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:comment_tree)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert changeset.valid?
    end

    test "raw_payload defaults to empty map" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.delete(:raw_payload)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert changeset.valid?
    end

    test "accepts :reddit as source" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.put(:source, :reddit)
      changeset = Thread.changeset(%Thread{}, attrs)
      assert changeset.valid?
    end

    test "accepts :elixirforum as source" do
      account = account_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:account_id, account.id)
        |> Map.put(:source, :elixirforum)
        |> Map.put(:url, "https://elixirforum.com/t/some-thread/12345")

      changeset = Thread.changeset(%Thread{}, attrs)
      assert changeset.valid?
    end

    test "rejects invalid source value" do
      account = account_fixture()
      attrs = @valid_attrs |> Map.put(:account_id, account.id) |> Map.put(:source, :twitter)
      changeset = Thread.changeset(%Thread{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).source
    end

    test "can be inserted and retrieved from the database" do
      account = account_fixture()
      attrs = Map.put(@valid_attrs, :account_id, account.id)
      changeset = Thread.changeset(%Thread{}, attrs)
      {:ok, thread} = MarketMySpec.Repo.insert(changeset)

      assert thread.id != nil
      assert thread.source == :reddit
      assert thread.source_thread_id == "abc123"
      assert thread.account_id == account.id
    end

    test "enforces uniqueness of account_id + source + source_thread_id" do
      account = account_fixture()
      attrs = Map.put(@valid_attrs, :account_id, account.id)

      {:ok, _} = MarketMySpec.Repo.insert(Thread.changeset(%Thread{}, attrs))
      {:error, changeset} = MarketMySpec.Repo.insert(Thread.changeset(%Thread{}, attrs))

      assert "has already been taken" in errors_on(changeset).source_thread_id
    end

    test "same source_thread_id allowed for different accounts" do
      account_a = account_fixture()
      account_b = account_fixture()

      attrs_a = Map.put(@valid_attrs, :account_id, account_a.id)
      attrs_b = Map.put(@valid_attrs, :account_id, account_b.id)

      assert {:ok, _} = MarketMySpec.Repo.insert(Thread.changeset(%Thread{}, attrs_a))
      assert {:ok, _} = MarketMySpec.Repo.insert(Thread.changeset(%Thread{}, attrs_b))
    end
  end
end

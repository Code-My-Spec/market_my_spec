defmodule MarketMySpec.Skills.MarketingStrategyTest do
  use ExUnit.Case, async: true

  alias MarketMySpec.Skills.MarketingStrategy

  describe "name/0" do
    test "returns the canonical skill identifier" do
      assert MarketingStrategy.name() == "marketing-strategy"
    end
  end

  describe "root_dir/0" do
    test "returns an absolute path under priv/skills/marketing-strategy" do
      root = MarketingStrategy.root_dir()

      assert Path.absname(root) == root
      assert String.ends_with?(root, "priv/skills/marketing-strategy")
    end
  end

  describe "read_skill_md/0" do
    test "returns the SKILL.md body with frontmatter and step references" do
      assert {:ok, body} = MarketingStrategy.read_skill_md()
      assert body =~ "name: marketing-strategy"
      assert body =~ "user-invocable: true"
      assert body =~ "steps/NN_*.md"
      assert body =~ "01_current_state.md"
      assert body =~ "08_plan.md"
    end
  end

  describe "read_skill_file/1" do
    test "returns step body for a valid relative path" do
      assert {:ok, body} = MarketingStrategy.read_skill_file("steps/01_current_state.md")
      assert is_binary(body)
      assert byte_size(body) > 0
    end

    test "returns each of the eight step bodies" do
      for n <- 1..8 do
        prefix = String.pad_leading(Integer.to_string(n), 2, "0")

        path =
          MarketingStrategy.root_dir()
          |> Path.join("steps")
          |> File.ls!()
          |> Enum.find(fn name -> String.starts_with?(name, prefix <> "_") end)

        assert path, "expected a step file with prefix #{prefix}_"
        assert {:ok, _body} = MarketingStrategy.read_skill_file("steps/#{path}")
      end
    end

    test "rejects parent-directory traversal" do
      assert {:error, :unsafe_path} =
               MarketingStrategy.read_skill_file("../../mix.exs")
    end

    test "rejects absolute paths" do
      assert {:error, :unsafe_path} = MarketingStrategy.read_skill_file("/etc/passwd")
    end

    test "rejects paths with embedded .. that resolve outside the root" do
      assert {:error, :unsafe_path} =
               MarketingStrategy.read_skill_file("steps/../../mix.exs")
    end

    test "returns enoent for files that don't exist inside the skill" do
      assert {:error, :enoent} =
               MarketingStrategy.read_skill_file("steps/99_nonexistent.md")
    end
  end
end

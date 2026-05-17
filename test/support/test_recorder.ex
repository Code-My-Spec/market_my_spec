defmodule MarketMySpec.TestRecorder do
  @moduledoc """
  Simple record/replay helper for testing.

  Records a function result to disk on the first run, then replays it
  on subsequent runs. Works with any Elixir term — HTTP responses,
  protobuf structs, database rows, etc.

  Distinct from `ReqCassette` (which intercepts Req requests at the
  Tesla/Req boundary); `TestRecorder` records the *result* of an
  arbitrary closure, so it suits tests that hold a decoded API response
  rather than the raw HTTP exchange.

  ## Usage

      result = MarketMySpec.TestRecorder.record_or_replay("my_cassette", fn ->
        expensive_api_call()
      end)

      assert result == expected

  Force re-record by deleting the cassette, setting `RERECORD=1`, or
  passing `force_record: true`.
  """

  @cassette_dir "test/cassettes"

  def record_or_replay(cassette_name, fun, opts \\ []) do
    force_record = Keyword.get(opts, :force_record, false)
    rerecord = System.get_env("RERECORD") in ["1", "true"]
    path = cassette_path(cassette_name)

    if File.exists?(path) and not force_record and not rerecord do
      replay(path)
    else
      record(path, fun)
    end
  end

  def delete_cassette(cassette_name) do
    cassette_name |> cassette_path() |> File.rm()
  end

  def delete_all_cassettes do
    if File.exists?(@cassette_dir), do: File.rm_rf!(@cassette_dir)
  end

  defp cassette_path(cassette_name) do
    Path.join(@cassette_dir, "#{cassette_name}.etf")
  end

  defp replay(path) do
    path |> File.read!() |> :erlang.binary_to_term()
  end

  defp record(path, fun) do
    result = fun.()
    File.mkdir_p!(@cassette_dir)
    File.write!(path, :erlang.term_to_binary(result))
    result
  end
end

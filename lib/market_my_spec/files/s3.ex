defmodule MarketMySpec.Files.S3 do
  @moduledoc """
  S3 implementation of `MarketMySpec.Files.Behaviour`. Default storage
  backend for the Files context.

  Uses `Req` with built-in AWS Signature V4 signing. Bucket, region, and
  AWS credentials are read from application config:

      config :market_my_spec, MarketMySpec.Files.S3,
        bucket: System.fetch_env!("S3_BUCKET"),
        region: System.fetch_env!("AWS_REGION"),
        access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")

  Keys reaching this module are already account-scoped (e.g.
  `accounts/42/marketing/05_positioning.md`); the Files context prefixes
  them before calling. The adapter never reasons about tenancy.
  """

  @behaviour MarketMySpec.Files.Behaviour

  @impl true
  def put(key, body, opts \\ []) when is_binary(key) and is_binary(body) and is_list(opts) do
    headers = put_headers(opts)

    case Req.put(object_url(key), body: body, headers: headers, aws_sigv4: aws_opts()) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, metadata_of(key, body, opts)}

      {:ok, %{status: status, body: error_body}} ->
        {:error, {:s3_error, status, error_body}}
    end
  end

  @impl true
  def get(key) when is_binary(key) do
    case Req.get(object_url(key), aws_sigv4: aws_opts()) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status, body: error_body}} -> {:error, {:s3_error, status, error_body}}
    end
  end

  @impl true
  def list(prefix) when is_binary(prefix) do
    query = URI.encode_query(%{"list-type" => "2", "prefix" => prefix})

    case Req.get("#{bucket_url()}?#{query}", aws_sigv4: aws_opts()) do
      {:ok, %{status: 200, body: body}} -> {:ok, parse_list_response(body)}
      {:ok, %{status: status, body: error_body}} -> {:error, {:s3_error, status, error_body}}
    end
  end

  @impl true
  def delete(key) when is_binary(key) do
    case Req.delete(object_url(key), aws_sigv4: aws_opts()) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status, body: error_body}} -> {:error, {:s3_error, status, error_body}}
    end
  end

  defp object_url(key), do: "#{bucket_url()}/#{URI.encode(key)}"

  defp bucket_url do
    config = config()
    "https://#{config[:bucket]}.s3.#{config[:region]}.amazonaws.com"
  end

  defp aws_opts do
    config = config()

    [
      access_key_id: config[:access_key_id],
      secret_access_key: config[:secret_access_key],
      service: "s3",
      region: config[:region]
    ]
  end

  defp put_headers(opts) do
    case Keyword.get(opts, :content_type) do
      nil -> []
      type -> [{"content-type", type}]
    end
  end

  defp metadata_of(key, body, opts) do
    base = %{key: key, size: byte_size(body), last_modified: DateTime.utc_now()}

    case Keyword.get(opts, :content_type) do
      nil -> base
      type -> Map.put(base, :content_type, type)
    end
  end

  defp parse_list_response(xml) when is_binary(xml) do
    keys = capture_all(xml, ~r/<Key>([^<]+)<\/Key>/)
    sizes = xml |> capture_all(~r/<Size>([^<]+)<\/Size>/) |> Enum.map(&String.to_integer/1)
    timestamps = xml |> capture_all(~r/<LastModified>([^<]+)<\/LastModified>/) |> Enum.map(&parse_iso8601/1)

    [keys, sizes, timestamps]
    |> Enum.zip()
    |> Enum.map(fn {key, size, last_modified} ->
      %{key: key, size: size, last_modified: last_modified}
    end)
  end

  defp parse_list_response(%{} = parsed) do
    parsed
    |> Map.get("ListBucketResult", %{})
    |> Map.get("Contents", [])
    |> List.wrap()
    |> Enum.map(fn entry ->
      %{
        key: entry["Key"],
        size: parse_int(entry["Size"]),
        last_modified: parse_iso8601(entry["LastModified"])
      }
    end)
  end

  defp capture_all(string, regex) do
    regex
    |> Regex.scan(string, capture: :all_but_first)
    |> List.flatten()
  end

  defp parse_iso8601(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_iso8601(_), do: nil

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_binary(value), do: String.to_integer(value)
  defp parse_int(_), do: 0

  defp config, do: Application.fetch_env!(:market_my_spec, __MODULE__)
end

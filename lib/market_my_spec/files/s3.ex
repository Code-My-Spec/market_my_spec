defmodule MarketMySpec.Files.S3 do
  @moduledoc """
  S3 implementation of `MarketMySpec.Files.Behaviour`. Default storage
  backend for the Files context.

  Uses `ExAws.S3` for Operation dispatch. Bucket is read from application
  config; AWS credentials and region are read from the `:ex_aws` application
  config (set via `config/runtime.exs` in production):

      config :ex_aws,
        access_key_id: "...",
        secret_access_key: "...",
        region: "us-east-1"

      config :market_my_spec, MarketMySpec.Files.S3,
        bucket: "market-my-spec-prod"

  Keys reaching this module are already account-scoped (e.g.
  `accounts/42/marketing/05_positioning.md`); the Files context prefixes
  them before calling. The adapter never reasons about tenancy.
  """

  @behaviour MarketMySpec.Files.Behaviour

  @impl true
  @spec put(MarketMySpec.Files.Behaviour.key(), MarketMySpec.Files.Behaviour.body(), MarketMySpec.Files.Behaviour.opts()) ::
          {:ok, MarketMySpec.Files.Behaviour.metadata()} | {:error, term()}
  def put(key, body, opts \\ []) when is_binary(key) and is_binary(body) and is_list(opts) do
    request_opts = put_request_opts(opts)

    bucket()
    |> ExAws.S3.put_object(key, body, request_opts)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, metadata_of(key, body, opts)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  @spec get(MarketMySpec.Files.Behaviour.key()) :: {:ok, MarketMySpec.Files.Behaviour.body()} | {:error, :not_found | term()}
  def get(key) when is_binary(key) do
    bucket()
    |> ExAws.S3.get_object(key)
    |> ExAws.request()
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, {:http_error, 404, _}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  @spec list(MarketMySpec.Files.Behaviour.prefix()) :: {:ok, [MarketMySpec.Files.Behaviour.metadata()]} | {:error, term()}
  def list(prefix) when is_binary(prefix) do
    bucket()
    |> ExAws.S3.list_objects_v2(prefix: prefix)
    |> ExAws.request()
    |> case do
      {:ok, %{body: %{contents: contents}}} -> {:ok, Enum.map(contents, &to_metadata/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  @spec delete(MarketMySpec.Files.Behaviour.key()) :: :ok | {:error, :not_found | term()}
  def delete(key) when is_binary(key) do
    bucket()
    |> ExAws.S3.delete_object(key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, {:http_error, 404, _}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_request_opts(opts) do
    case Keyword.get(opts, :content_type) do
      nil -> []
      type -> [content_type: type]
    end
  end

  defp metadata_of(key, body, opts) do
    base = %{key: key, size: byte_size(body), last_modified: DateTime.utc_now()}

    case Keyword.get(opts, :content_type) do
      nil -> base
      type -> Map.put(base, :content_type, type)
    end
  end

  defp to_metadata(%{key: key, size: size, last_modified: last_modified}) do
    %{
      key: key,
      size: parse_size(size),
      last_modified: parse_iso8601(last_modified)
    }
  end

  defp parse_size(size) when is_integer(size), do: size
  defp parse_size(size) when is_binary(size), do: String.to_integer(size)
  defp parse_size(_), do: 0

  defp parse_iso8601(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_iso8601(_), do: nil

  defp bucket, do: Application.fetch_env!(:market_my_spec, __MODULE__)[:bucket]
end

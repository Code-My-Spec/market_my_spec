defmodule MarketMySpec.Secrets do
  @moduledoc """
  Boot-time secret loader. Pulls every parameter under
  `/market_my_spec/<APP_ENV>/` from AWS SSM Parameter Store and writes
  it into the OS environment so the rest of `config/runtime.exs` (which
  uses `Dotenvy.env!/3` over `System.get_env`) sees the values as if
  they were set in the container's launch env.

  Invoked from the top of `config/runtime.exs` in `:prod`. Local dev
  does not call this — dev secrets come from `.env` files via Dotenvy.

  Mirrors the metric_flow pattern; see that repo's
  `priv/knowledge/devops/secrets-runtime.md` for the design notes.

  ## IAM

  Uses the standard ExAws credential chain. The container needs an IAM
  principal scoped to:
  - `ssm:GetParametersByPath` on
    `arn:aws:ssm:us-east-1:889081505590:parameter/market_my_spec/<env>/*`
    (per-app, per-env user — `market-my-spec-<env>-app`)
  - `kms:Decrypt` on the SSM service KMS key

  Creds are passed in via `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`,
  region defaults to `AWS_REGION` (set to us-east-1 in our deploys).
  """

  @path_prefix "/market_my_spec/"

  @max_attempts 3
  @backoff_ms 1000

  @spec load!(String.t()) :: :ok
  def load!(app_env) when app_env in ["prod", "uat"] do
    {:ok, _} = Application.ensure_all_started(:ex_aws)
    {:ok, _} = Application.ensure_all_started(:hackney)

    path = @path_prefix <> app_env <> "/"

    parameters = fetch_all(path, nil, [])

    if parameters == [] do
      raise """
      No SSM parameters found under #{path}.
      Verify AWS credentials and that the path has parameters.
      """
    end

    Enum.each(parameters, fn %{"Name" => name, "Value" => value} ->
      key = String.replace_prefix(name, path, "")
      System.put_env(key, value)
    end)

    :ok
  end

  def load!(other),
    do: raise(ArgumentError, "MarketMySpec.Secrets.load!/1: unsupported APP_ENV #{inspect(other)}")

  defp fetch_all(path, next_token, acc) do
    case fetch_page(path, next_token) do
      {:ok, %{"Parameters" => params, "NextToken" => token}} when is_binary(token) ->
        fetch_all(path, token, [params | acc])

      {:ok, %{"Parameters" => params}} ->
        Enum.reverse([params | acc]) |> List.flatten()
    end
  end

  defp fetch_page(path, next_token, attempt \\ 1) do
    opts = [recursive: true, with_decryption: true]
    opts = if next_token, do: Keyword.put(opts, :next_token, next_token), else: opts

    case ExAws.SSM.get_parameters_by_path(path, opts) |> ExAws.request() do
      {:ok, page} ->
        {:ok, page}

      {:error, _reason} when attempt < @max_attempts ->
        :logger.warning(
          "MarketMySpec.Secrets: SSM fetch failed for #{path} (attempt #{attempt}/#{@max_attempts}); retrying in #{@backoff_ms}ms"
        )

        Process.sleep(@backoff_ms)
        fetch_page(path, next_token, attempt + 1)

      {:error, reason} ->
        raise """
        MarketMySpec.Secrets.load!/1: SSM fetch failed for #{path} after \
        #{@max_attempts} attempts: #{inspect(reason)}
        """
    end
  end
end

defmodule MarketMySpec.Mailer do
  use Swoosh.Mailer, otp_app: :market_my_spec

  @default_from {"MarketMySpec", "noreply@marketmyspec.com"}

  @doc """
  The `{name, address}` tuple all outbound mail is sent from.

  Configured via `config :market_my_spec, :mail_from` (set from the
  `MAIL_FROM` env in `config/runtime.exs`). The address must be on a domain
  verified in Resend, or sends are rejected.
  """
  def from, do: Application.get_env(:market_my_spec, :mail_from, @default_from)
end

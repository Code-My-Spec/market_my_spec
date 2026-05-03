defmodule MarketMySpecWeb.PageController do
  use MarketMySpecWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

defmodule MarketMySpecWeb.FilesLive.Show do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Files

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@key}
        <:subtitle>Artifact contents</:subtitle>
        <:actions>
          <.link navigate={~p"/files"} class="btn btn-sm">Back</.link>
        </:actions>
      </.header>

      <article :if={@rendered_html} class="prose prose-invert max-w-none mt-6">
        {Phoenix.HTML.raw(@rendered_html)}
      </article>
      <pre :if={@raw_body} class="mt-6 p-4 bg-base-200 rounded text-sm whitespace-pre-wrap">{@raw_body}</pre>
      <p :if={@error} class="mt-6 text-error">{@error}</p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"key" => key_segments}, _session, socket) do
    key = Enum.join(List.wrap(key_segments), "/")
    scope = socket.assigns.current_scope

    case Files.get(scope, key) do
      {:ok, body} ->
        {:ok, assign_body(socket, key, body)}

      {:error, :no_active_account} ->
        {:ok,
         socket
         |> put_flash(:error, "No active account. Please select an account first.")
         |> push_navigate(to: ~p"/accounts")}

      {:error, _reason} ->
        {:ok,
         assign(socket, key: key, rendered_html: nil, raw_body: nil, error: "File not available.")}
    end
  end

  defp assign_body(socket, key, body) do
    if markdown?(key) do
      assign(socket, key: key, rendered_html: render_markdown(body), raw_body: nil, error: nil)
    else
      assign(socket, key: key, rendered_html: nil, raw_body: body, error: nil)
    end
  end

  defp markdown?(key) do
    String.downcase(Path.extname(key)) in [".md", ".markdown"]
  end

  defp render_markdown(body) do
    MDEx.to_html!(body,
      extension: [
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      render: [unsafe: false]
    )
  end
end

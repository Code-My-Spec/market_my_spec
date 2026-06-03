defmodule MarketMySpecWeb.PrivacyLive do
  @moduledoc """
  Public privacy policy page.

  Served at `/privacy` with no authentication. Exists in part to satisfy the
  Google OAuth consent-screen requirement that the app expose a privacy
  policy URL on its verified homepage domain.
  """
  use MarketMySpecWeb, :live_view

  @last_updated "June 3, 2026"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Privacy Policy", last_updated: @last_updated)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.marketing
      flash={@flash}
      current_scope={@current_scope}
      current_agency={@current_agency}
    >
      <article class="prose prose-base max-w-none">
        <h1 class="font-display text-3xl">Privacy Policy</h1>
        <p class="text-base-content/60">Last updated: {@last_updated}</p>

        <p>
          MarketMySpec ("we", "us") helps founders run developer marketing from
          inside their AI coding tools. This policy explains what we collect, why,
          and the choices you have. Questions: <a href="mailto:johns10@gmail.com">johns10@gmail.com</a>.
        </p>

        <h2>Information we collect</h2>
        <ul>
          <li>
            <strong>Account information.</strong>
            When you sign in with Google or GitHub we receive your name, email
            address, and profile avatar to create and identify your account.
          </li>
          <li>
            <strong>Content you create.</strong>
            Searches, venues, touchpoints, files, and other data you produce while
            using the product.
          </li>
          <li>
            <strong>Connected integrations.</strong>
            When you authorize a third-party integration (for example, Google) we
            store the OAuth tokens needed to act on your behalf, limited to the
            scopes you grant. We request only the scopes a feature requires and you
            can revoke access at any time.
          </li>
          <li>
            <strong>Usage and technical data.</strong>
            Standard server logs and basic analytics about how the service is used,
            to keep it running and improve it.
          </li>
        </ul>

        <h2>How we use information</h2>
        <ul>
          <li>To provide, maintain, and improve the service.</li>
          <li>To authenticate you and secure your account.</li>
          <li>
            To perform the actions you explicitly request through connected
            integrations.
          </li>
          <li>To communicate with you about your account and the service.</li>
        </ul>

        <h2>Google user data</h2>
        <p>
          When you sign in with Google we use your basic profile and email solely
          to create your account and identify you. MarketMySpec's use of
          information received from Google APIs adheres to the
          <a
            href="https://developers.google.com/terms/api-services-user-data-policy"
            target="_blank"
            rel="noopener"
          >Google API Services User Data Policy</a>, including the Limited Use
          requirements. We do not sell Google user data, and we do not use it for
          advertising.
        </p>

        <h2>How we share information</h2>
        <p>
          We do not sell your personal information. We share data only with service
          providers that help us operate the product (such as hosting and email
          delivery), and only as needed to provide the service, or when required by
          law.
        </p>

        <h2>Data retention</h2>
        <p>
          We retain your information for as long as your account is active. You may
          request deletion of your account and associated data by emailing us.
        </p>

        <h2>Your choices</h2>
        <ul>
          <li>Revoke a connected integration at any time from your account settings or the provider.</li>
          <li>Request access to, correction of, or deletion of your data by contacting us.</li>
        </ul>

        <h2>Changes to this policy</h2>
        <p>
          We may update this policy from time to time. Material changes will be
          reflected by updating the "Last updated" date above.
        </p>

        <h2>Contact</h2>
        <p>
          MarketMySpec — <a href="mailto:johns10@gmail.com">johns10@gmail.com</a>
        </p>
      </article>
    </Layouts.marketing>
    """
  end
end

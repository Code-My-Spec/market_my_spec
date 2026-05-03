# Future Issues

Deferred stories — not in MVP scope. Revisit when agency onboarding matures.

## Agency White Label Branding

As an agency owner, I want to configure my agency's branding — logo URL, primary color, secondary color, and a unique subdomain — so that when my clients access Market My Spec through my subdomain they see my agency's brand rather than the platform's default branding.

The agency configures branding in their account settings. Once a subdomain is set and verified, any visitor arriving at that subdomain sees the agency logo and color palette applied to the UI. The subdomain must be globally unique and follow alphanumeric-plus-hyphen format (3–63 characters).

## Agency Custom Domain

As an agency owner, I want to point my own fully-qualified domain name (e.g. marketing.myagency.com) at the platform and have it serve my white-labeled instance, so that my clients land on a URL I own rather than a market-my-spec subdomain.

The agency enters a custom domain in their white label settings. The platform provides a CNAME target for DNS configuration. The domain only goes live after DNS verification confirms the CNAME record resolves correctly. Unverified domains do not resolve to any white-label config.

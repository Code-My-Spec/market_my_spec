# Dockerfile for MarketMySpec Phoenix app
# Build on ARM64 (Hetzner cax11)

ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.0.1
ARG DEBIAN_VERSION=bookworm-20260223-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build stage ----
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy all application code
COPY priv priv
COPY lib lib
COPY assets assets

# Copy runtime config and Phoenix release overlays
COPY config/runtime.exs config/
COPY rel rel

# Dotenvy in runtime.exs sources ./envs/.env and ./envs/<env>.env. In Docker
# all env vars come via --env-file so the files don't exist; keep Dotenvy
# happy by giving it empty placeholders.
RUN mkdir -p envs && touch envs/.env envs/prod.env

# Install npm deps used by esbuild (e.g. html-to-image for the
# CodeMySpec feedback widget's screenshot capture). Done before
# assets.deploy so esbuild can resolve the imports.
RUN cd assets && npm install --no-audit --no-fund --no-progress

# Compile and build assets
RUN mix compile

# `mix assets.deploy` downloads platform-specific tailwind + esbuild binaries
# from GitHub releases / npm on first run. Both endpoints occasionally 504,
# especially on arm64 (see CI history). Retry up to 5x with linear backoff so
# a transient gateway timeout doesn't fail the build.
RUN for attempt in 1 2 3 4 5; do \
      if mix assets.deploy; then \
        echo "assets.deploy succeeded on attempt $attempt"; \
        break; \
      fi; \
      if [ "$attempt" = "5" ]; then \
        echo "assets.deploy failed after 5 attempts" >&2; \
        exit 1; \
      fi; \
      sleep_for=$((attempt * 5)); \
      echo "assets.deploy failed on attempt $attempt — sleeping ${sleep_for}s before retry"; \
      sleep "$sleep_for"; \
    done

# Build release
RUN mix release

# ---- Runner stage ----
FROM ${RUNNER_IMAGE}

# Vale CLI version pinned. Updates are a one-line diff. See
# .code_my_spec/knowledge/vale-cli.md.
ARG VALE_VERSION=3.14.2

# TARGETARCH is set by buildx for multi-arch builds (amd64 | arm64).
# Vale releases name the amd64 asset "64-bit" and the arm64 asset "arm64".
ARG TARGETARCH

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates curl tar \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Vale prose-lint binary for the build platform. Vendored styles
# ship inside the Elixir release at priv/vale/styles; the binary itself
# is platform-specific and lives outside the BEAM release.
RUN case "${TARGETARCH:-amd64}" in \
      amd64) VALE_ARCH=64-bit ;; \
      arm64) VALE_ARCH=arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -sSL "https://github.com/errata-ai/vale/releases/download/v${VALE_VERSION}/vale_${VALE_VERSION}_Linux_${VALE_ARCH}.tar.gz" -o /tmp/vale.tar.gz \
    && tar -xzf /tmp/vale.tar.gz -C /usr/local/bin vale \
    && rm /tmp/vale.tar.gz \
    && vale --version

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/market_my_spec ./

USER nobody

CMD ["/app/bin/server"]

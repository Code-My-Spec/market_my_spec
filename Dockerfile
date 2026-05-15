# Dockerfile for MarketMySpec Phoenix app
# Build on ARM64 (Hetzner cax11)

ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.0.1
ARG DEBIAN_VERSION=bookworm-20260223-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build stage ----
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl \
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

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

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

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.1
ARG ALPINE_VERSION=3.21.3

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

RUN mkdir config
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets
COPY rel rel

RUN mix compile
RUN mix assets.deploy
RUN mix release

FROM ${RUNNER_IMAGE} AS runner

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

ENV MIX_ENV=prod

COPY --from=builder /app/_build/prod/rel/phoenix_fintech ./
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/bin/server"]

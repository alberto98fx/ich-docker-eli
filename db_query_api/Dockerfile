FROM elixir:1.12-alpine

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

COPY mix.exs ./
RUN mix deps.get

COPY . .

RUN apk add mysql mysql-client 
RUN mix compile
EXPOSE 4000
CMD ["mix", "run", "--no-halt"]

# Ueberauth.Strategy.Line

**Deprecated. Consider using [assent](https://github.com/pow-auth/assent) instead, as it is well-supported and has a better story in using alternative HTTP libraries.**

Ueberauth strategy for [Line Login](https://developers.line.biz/en/docs/line-login/).

[![CI](https://github.com/itswindtw/ueberauth_strategy_line/actions/workflows/ci.yml/badge.svg)](https://github.com/itswindtw/ueberauth_strategy_line/actions/workflows/ci.yml)

## Installation

In mix.exs:

```elixir
def deps do
  [
    {:ueberauth_strategy_line, github: "itswindtw/ueberauth_strategy_line"}
  ]
end
```

In config:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    line: {Ueberauth.Strategy.Line, []}
  ]

config :ueberauth, Ueberauth.Strategy.Line,
  client_id: "",
  client_secret: ""
```

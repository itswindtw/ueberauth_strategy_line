alias Ueberauth.Strategy.Line

Application.put_env(:ueberauth, Line,
  client_id: "client_id",
  client_secret: "client_secret"
)

Mox.defmock(Line.DateTime.Mock, for: Line.DateTime)
Application.put_env(:ueberauth_strategy_line, Line.DateTime, Line.DateTime.Mock)

Mox.defmock(Line.API.Mock, for: Line.API)
Application.put_env(:ueberauth_strategy_line, Line.API, Line.API.Mock)

ExUnit.start()

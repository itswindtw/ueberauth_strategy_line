defmodule Ueberauth.Strategy.Line.Application do
  @moduledoc false

  use Application

  alias Ueberauth.Strategy.Line

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Line.Finch}
    ]

    opts = [strategy: :one_for_one, name: Line.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Ueberauth.Strategy.Line.DateTime do
  @moduledoc false

  @callback utc_now() :: DateTime.t()

  def utc_now do
    impl().utc_now()
  end

  defp impl, do: Application.get_env(:ueberauth_strategy_line, __MODULE__, DateTime)
end

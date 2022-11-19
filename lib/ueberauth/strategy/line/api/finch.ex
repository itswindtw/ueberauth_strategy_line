defmodule Ueberauth.Strategy.Line.API.Finch do
  @moduledoc false

  @behaviour Ueberauth.Strategy.Line.API

  def issue_access_token(client_id, client_secret, redirect_uri, code) do
    Finch.build(
      :post,
      "https://api.line.me/oauth2/v2.1/token",
      [{"Content-Type", "application/x-www-form-urlencoded"}],
      URI.encode_query(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: client_id,
        client_secret: client_secret
      )
    )
    |> Finch.request(Ueberauth.Strategy.Line.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200} = resp} ->
        {:ok, resp.body}

      {:ok, resp} ->
        {:error, inspect(resp)}

      {:error, e} ->
        {:error, e}
    end
  end
end

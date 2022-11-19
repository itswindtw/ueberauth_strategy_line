defmodule Ueberauth.Strategy.Line do
  @moduledoc false

  use Ueberauth.Strategy

  alias Ueberauth.Auth
  alias Ueberauth.Strategy.Line

  @private_prefix :ueberauth_strategy_line_
  @private_json :"#{@private_prefix}json"
  @private_jwt :"#{@private_prefix}jwt"

  def handle_request!(conn) do
    client_id = Keyword.fetch!(config(), :client_id)
    redirect_uri = callback_url(conn)
    scopes = get_option(conn, :scopes, ["profile", "openid"])
    opts = get_option(conn, :authorize_options, []) |> with_state_param(conn)

    authorize_url = Line.API.authorize_url(client_id, redirect_uri, scopes, opts)

    redirect!(conn, authorize_url)
  end

  @dialyzer {:no_match, {:handle_callback!, 1}}

  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    client_id = Keyword.fetch!(config(), :client_id)
    client_secret = Keyword.fetch!(config(), :client_secret)
    redirect_uri = callback_url(conn)

    with {:ok, resp_data} <-
           Line.API.issue_access_token(client_id, client_secret, redirect_uri, code),
         {:ok, json} <- Jason.decode(resp_data),
         {:ok, jwt} <- Line.API.parse_id_token(client_secret, Map.get(json, "id_token")) do
      conn
      |> put_private(@private_json, json)
      |> put_private(@private_jwt, jwt)
    else
      {:error, reason} ->
        message = if is_exception(reason), do: Exception.message(reason), else: reason

        set_errors!(conn, [error("callback_error", message)])
    end
  end

  def handle_callback!(conn) do
    message =
      conn.params["error_description"] || conn.params["error"] || "Unrecognized token response"

    set_errors!(conn, [error("callback_error", message)])
  end

  def handle_cleanup!(conn) do
    conn
    |> put_private(@private_json, nil)
    |> put_private(@private_jwt, nil)
  end

  def uid(conn) do
    jwt = Map.fetch!(conn.private, @private_jwt)

    Map.get(jwt, "sub")
  end

  def info(conn) do
    jwt = Map.fetch!(conn.private, @private_jwt)

    %Auth.Info{
      email: Map.get(jwt, "email"),
      image: Map.get(jwt, "picture"),
      name: Map.get(jwt, "name")
    }
  end

  def extra(_conn) do
    %Auth.Extra{}
  end

  def credentials(conn) do
    json = Map.fetch!(conn.private, @private_json)

    {expires, expires_at} =
      if expires_in = Map.get(json, "expires_in") do
        now = Line.DateTime.utc_now()
        expires_at = DateTime.add(now, expires_in) |> DateTime.to_unix()

        {false, expires_at}
      else
        {nil, nil}
      end

    %Auth.Credentials{
      expires: expires,
      expires_at: expires_at,
      refresh_token: Map.get(json, "refresh_token"),
      scopes: Map.get(json, "scope", "") |> String.split(" "),
      token: Map.get(json, "access_token"),
      token_type: Map.get(json, "token_type")
    }
  end

  # Helpers

  defp config do
    Application.get_env(:ueberauth, __MODULE__)
  end

  defp get_option(conn, key, default) do
    Keyword.get(options(conn), key, default)
  end
end

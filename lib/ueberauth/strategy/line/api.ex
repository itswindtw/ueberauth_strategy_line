defmodule Ueberauth.Strategy.Line.API do
  @moduledoc false

  @callback issue_access_token(binary(), binary(), binary(), binary()) ::
              {:ok, binary()} | {:error, binary() | Exception.t()}

  def authorize_url(client_id, redirect_uri, scopes, opts) do
    opts =
      Keyword.merge(opts,
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: Enum.join(scopes, " ")
      )

    URI.new!("https://access.line.me/oauth2/v2.1/authorize")
    |> URI.append_query(URI.encode_query(opts))
    |> URI.to_string()
  end

  def issue_access_token(client_id, client_secret, redirect_uri, code) do
    impl().issue_access_token(client_id, client_secret, redirect_uri, code)
  end

  def parse_id_token(_client_secret, nil) do
    {:error, "No id_token received"}
  end

  def parse_id_token(client_secret, raw) do
    with [header, payload, signature] <- String.split(raw, ".", parts: 3),
         {:ok, signature} <- Base.url_decode64(signature, padding: false),
         true <- valid_signature?(client_secret, "#{header}.#{payload}", signature),
         {:ok, payload} <- Base.url_decode64(payload, padding: false),
         {:ok, payload} <- Jason.decode(payload) do
      {:ok, payload}
    else
      _ -> {:error, "Invalid id_token: #{raw}"}
    end
  end

  def valid_signature?(key, raw, signature) do
    computed = :crypto.mac(:hmac, :sha256, key, raw)
    computed == signature
  end

  defp impl, do: Application.get_env(:ueberauth_strategy_line, __MODULE__, __MODULE__.Finch)
end

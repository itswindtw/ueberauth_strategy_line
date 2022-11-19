defmodule Ueberauth.Strategy.LineTest do
  use ExUnit.Case
  use Plug.Test

  import Mox

  alias Ueberauth.Strategy.Line
  alias Ueberauth.Auth

  @json_key :ueberauth_strategy_line_json
  @jwt_key :ueberauth_strategy_line_jwt

  test "handle_request!/1" do
    conn =
      build_ueberauth_conn(:get, "/auth/line")
      |> Line.handle_request!()

    redirected_to = get_resp_header(conn, "location") |> List.first() |> URI.parse()

    assert redirected_to.scheme == "https"
    assert redirected_to.host == "access.line.me"
    assert redirected_to.path == "/oauth2/v2.1/authorize"

    query_params = URI.decode_query(redirected_to.query)

    assert query_params["client_id"] == "client_id"
    assert query_params["response_type"] == "code"
    assert query_params["redirect_uri"] == "http://www.example.com"
    assert query_params["scope"] == "profile openid"
  end

  describe "handle_callback!/1" do
    @sample_code "abcd1234"

    test "happy path" do
      Line.API.Mock
      |> expect(:issue_access_token, fn client_id, client_secret, redirect_uri, code ->
        assert client_id == "client_id"
        assert client_secret == "client_secret"
        assert redirect_uri == "http://www.example.com"
        assert code == @sample_code

        {:ok, Jason.encode!(build_resp_data())}
      end)

      conn =
        build_ueberauth_conn(:get, "/auth/line/callback?code=#{@sample_code}")
        |> Line.handle_callback!()

      assert conn.private.ueberauth_strategy_line_json
      assert conn.private.ueberauth_strategy_line_jwt
    end

    test "id_token is missing" do
      Line.API.Mock
      |> expect(:issue_access_token, fn _client_id, _client_secret, _redirect_uri, _code ->
        resp_data =
          build_resp_data()
          |> Map.delete("id_token")

        {:ok, Jason.encode!(resp_data)}
      end)

      conn =
        build_ueberauth_conn(:get, "/auth/line/callback?code=#{@sample_code}")
        |> Line.handle_callback!()

      assert_ueberauth_failure(conn, "No id_token received")
    end

    test "id_token is invalid" do
      Line.API.Mock
      |> expect(:issue_access_token, fn _client_id, _client_secret, _redirect_uri, _code ->
        resp_data =
          build_resp_data()
          |> Map.put("id_token", "1234")

        {:ok, Jason.encode!(resp_data)}
      end)

      conn =
        build_ueberauth_conn(:get, "/auth/line/callback?code=#{@sample_code}")
        |> Line.handle_callback!()

      assert_ueberauth_failure(conn, "Invalid id_token: 1234")
    end

    defp build_resp_data do
      header =
        %{"typ" => "JWT", "alg" => "HS256"}
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      payload =
        %{
          "iss" => "https://access.line.me",
          "sub" => "U1234567890abcdef1234567890abcdef ",
          "aud" => "1234567890",
          "exp" => 1_504_169_092,
          "iat" => 1_504_263_657,
          "nonce" => "0987654asdf",
          "amr" => ["pwd"],
          "name" => "Taro Line",
          "picture" => "https://sample_line.me/aBcdefg123456"
        }
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      sig =
        :crypto.mac(:hmac, :sha256, "client_secret", "#{header}.#{payload}")
        |> Base.url_encode64(padding: false)

      id_token = "#{header}.#{payload}.#{sig}"

      %{
        "access_token" => "bNl4YEFPI/hjFWhTqexp4MuEw5YPs...",
        "expires_in" => 2_592_000,
        "id_token" => id_token,
        "refresh_token" => "Aa1FdeggRhTnPNNpxr8p",
        "scope" => "profile",
        "token_type" => "Bearer"
      }
    end

    test "error_description in params" do
      conn =
        build_ueberauth_conn(:get, "/auth/line/callback?error_description=Oops")
        |> Line.handle_callback!()

      assert_ueberauth_failure(conn, "Oops")
    end

    test "issue_access_token returns error" do
      Line.API.Mock
      |> expect(:issue_access_token, fn _client_id, _client_secret, _redirect_uri, _code ->
        {:error, %RuntimeError{message: "Oops"}}
      end)

      conn =
        build_ueberauth_conn(:get, "/auth/line/callback?code=123")
        |> Line.handle_callback!()

      assert_ueberauth_failure(conn, "Oops")
    end

    defp assert_ueberauth_failure(conn, message) do
      error = conn.assigns.ueberauth_failure.errors |> List.first()
      assert error.message == message
    end
  end

  defp build_ueberauth_conn(method, path) do
    conn(method, path)
    |> put_in([Access.key!(:private), Access.key(:ueberauth_request_options, []), :options], [])
    |> fetch_query_params()
  end

  describe "with handled conn" do
    setup do
      private =
        %{}
        |> Map.put(@json_key, %{
          "access_token" => "bNl4YEFPI/hjFWhTqexp4MuEw5YPs...",
          "expires_in" => 2_592_000,
          "id_token" => "eyJhbGciOiJIUzI1NiJ9...",
          "refresh_token" => "Aa1FdeggRhTnPNNpxr8p",
          "scope" => "profile",
          "token_type" => "Bearer"
        })
        |> Map.put(@jwt_key, %{
          "iss" => "https://access.line.me",
          "sub" => "U1234567890abcdef1234567890abcdef",
          "aud" => "1234567890",
          "exp" => 1_504_169_092,
          "iat" => 1_504_263_657,
          "nonce" => "0987654asdf",
          "amr" => ["pwd"],
          "name" => "Taro Line",
          "picture" => "https://sample_line.me/aBcdefg123456",
          "email" => "taro.line@example.com"
        })

      {:ok, conn: %Plug.Conn{private: private}}
    end

    test "handle_cleanup!/1", %{conn: conn} do
      conn = Line.handle_cleanup!(conn)

      assert Map.fetch!(conn.private, @json_key) == nil
      assert Map.fetch!(conn.private, @jwt_key) == nil
    end

    test "uid/1", %{conn: conn} do
      assert Line.uid(conn) == "U1234567890abcdef1234567890abcdef"
    end

    test "info/1", %{conn: conn} do
      assert Line.info(conn) == %Auth.Info{
               email: "taro.line@example.com",
               image: "https://sample_line.me/aBcdefg123456",
               name: "Taro Line"
             }
    end

    test "extra/1", %{conn: conn} do
      assert Line.extra(conn) == %Auth.Extra{}
    end

    test "credentials/1", %{conn: conn} do
      Line.DateTime.Mock
      |> expect(:utc_now, fn -> DateTime.new!(Date.new!(2022, 11, 11), Time.new!(11, 11, 11)) end)

      assert Line.credentials(conn) == %Auth.Credentials{
               expires: false,
               expires_at: 1_670_757_071,
               refresh_token: "Aa1FdeggRhTnPNNpxr8p",
               scopes: ["profile"],
               token: "bNl4YEFPI/hjFWhTqexp4MuEw5YPs...",
               token_type: "Bearer"
             }
    end
  end
end

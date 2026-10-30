defmodule IeeeTamuPortal.Github.Auth do
  @moduledoc """
  Provides installation access tokens for the IEEE TAMU GitHub App.

  GitHub Apps authenticate with a short-lived RS256 JWT, which is exchanged for
  an installation access token. Tokens are cached until shortly before expiry.

  Tests (and local development) may provide a static token with:

      config :ieee_tamu_portal, :github_installation_token, "ghs_..."
  """

  use GenServer

  require Logger

  @refresh_margin_seconds 60
  @default_api_url "https://api.github.com"

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Returns `{:ok, token}` for the configured GitHub App installation.
  """
  def token do
    case Application.get_env(:ieee_tamu_portal, :github_installation_token) do
      token when is_binary(token) and token != "" ->
        {:ok, token}

      _ ->
        if Process.whereis(__MODULE__) do
          GenServer.call(__MODULE__, :token)
        else
          {:error, :not_configured}
        end
    end
  end

  @impl true
  def init(_opts) do
    {:ok, %{token: nil, expires_at: nil}}
  end

  @impl true
  def handle_call(:token, _from, state) do
    if valid_token?(state) do
      {:reply, {:ok, state.token}, state}
    else
      case fetch_token() do
        {:ok, token, expires_at} ->
          {:reply, {:ok, token}, %{token: token, expires_at: expires_at}}

        {:error, reason} ->
          Logger.error("Failed to obtain GitHub installation token: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  defp valid_token?(%{token: token, expires_at: expires_at}) do
    is_binary(token) and match?(%DateTime{}, expires_at) and
      DateTime.compare(
        expires_at,
        DateTime.add(DateTime.utc_now(), @refresh_margin_seconds, :second)
      ) == :gt
  end

  defp fetch_token do
    with {:ok, config} <- IeeeTamuPortal.Features.get_config(:github_org),
         {:ok, jwt} <- build_jwt(config[:app_id], config[:private_key]),
         {:ok, body} <- request_installation_token(config[:installation_id], jwt) do
      expires_at =
        case DateTime.from_iso8601(body["expires_at"] || "") do
          {:ok, expires_at, _offset} -> expires_at
          _ -> DateTime.add(DateTime.utc_now(), 50 * 60, :second)
        end

      {:ok, body["token"], expires_at}
    end
  end

  defp request_installation_token(installation_id, jwt) do
    url = "#{api_url()}/app/installations/#{installation_id}/access_tokens"

    headers = [
      {"accept", "application/vnd.github+json"},
      {"authorization", "Bearer #{jwt}"},
      {"x-github-api-version", "2022-11-28"},
      {"user-agent", "ieee-tamu-portal"}
    ]

    case Req.post(url, [headers: headers, json: %{}] ++ req_options()) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in [200, 201] and is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "GitHub token request failed: #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_jwt(app_id, private_key) do
    now = System.system_time(:second)

    header =
      %{"alg" => "RS256", "typ" => "JWT"}
      |> Jason.encode!()
      |> base64url()

    payload =
      %{"iat" => now - 60, "exp" => now + 540, "iss" => app_id}
      |> Jason.encode!()
      |> base64url()

    signing_input = header <> "." <> payload

    with {:ok, key} <- decode_private_key(private_key) do
      signature = :public_key.sign(signing_input, :sha256, key)
      {:ok, signing_input <> "." <> base64url(signature)}
    end
  end

  defp decode_private_key(pem) when is_binary(pem) do
    case :public_key.pem_decode(pem) do
      [entry | _] -> {:ok, :public_key.pem_entry_decode(entry)}
      _ -> {:error, :invalid_private_key}
    end
  rescue
    _ -> {:error, :invalid_private_key}
  end

  defp decode_private_key(_), do: {:error, :invalid_private_key}

  defp base64url(data), do: Base.url_encode64(data, padding: false)

  defp api_url do
    Application.get_env(:ieee_tamu_portal, :github_api_url, @default_api_url)
  end

  defp req_options do
    Application.get_env(:ieee_tamu_portal, :github_req_opts, [])
  end
end

defmodule IeeeTamuPortalWeb.Upload.SimpleS3Upload do
  @moduledoc """
  Below is code from Chris McCord, modified for Cloudflare R2

  https://gist.github.com/chrismccord/37862f1f8b1f5148644b75d20d1cb073

  """
  @one_hour_seconds 3600

  defp region, do: Application.fetch_env!(:ieee_tamu_portal, __MODULE__)[:region]
  defp access_key_id, do: Application.fetch_env!(:ieee_tamu_portal, __MODULE__)[:access_key_id]

  defp secret_access_key,
    do: Application.fetch_env!(:ieee_tamu_portal, __MODULE__)[:secret_access_key]

  def bucket_url, do: Application.fetch_env!(:ieee_tamu_portal, __MODULE__)[:url]

  defp uri(opts) do
    case Keyword.get(opts, :uri) do
      nil ->
        key = Keyword.fetch!(opts, :key)
        "#{bucket_url()}/#{key}"

      uri when is_binary(uri) ->
        uri
    end
  end

  def sign(opts) do
    expires_in = Keyword.get(opts, :expires_in, @one_hour_seconds)

    method = Keyword.fetch!(opts, :method)

    uri = uri(opts)

    url =
      :aws_signature.sign_v4_query_params(
        access_key_id(),
        secret_access_key(),
        region(),
        "s3",
        :calendar.universal_time(),
        method,
        uri,
        ttl: expires_in,
        body_digest: "UNSIGNED-PAYLOAD"
      )

    {:ok, url}
  end
end

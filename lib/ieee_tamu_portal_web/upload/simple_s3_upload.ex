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

  @doc """
    Returns `{:ok, presigned_url}` where `presigned_url` is a url string

  """
  def presigned_put(opts) do
    expires_in = Keyword.get(opts, :expires_in, @one_hour_seconds)

    uri =
      case Keyword.get(opts, :key) do
        nil -> Keyword.fetch!(opts, :uri)
        key -> "#{bucket_url()}/#{URI.encode(key)}"
      end

    url =
      :aws_signature.sign_v4_query_params(
        access_key_id(),
        secret_access_key(),
        region(),
        "s3",
        :calendar.universal_time(),
        "PUT",
        uri,
        ttl: expires_in,
        body_digest: "UNSIGNED-PAYLOAD"
      )

    {:ok, url}
  end

  def presigned_get(opts) do
    expires_in = Keyword.get(opts, :expires_in, @one_hour_seconds)

    uri =
      case Keyword.get(opts, :key) do
        nil -> Keyword.fetch!(opts, :uri)
        key -> "#{bucket_url()}/#{URI.encode(key)}"
      end

    url =
      :aws_signature.sign_v4_query_params(
        access_key_id(),
        secret_access_key(),
        region(),
        "s3",
        :calendar.universal_time(),
        "GET",
        uri,
        ttl: expires_in,
        body_digest: "UNSIGNED-PAYLOAD"
      )

    {:ok, url}
  end
end

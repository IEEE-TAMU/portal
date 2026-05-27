defmodule IeeeTamuPortalWeb.Upload.SimpleS3Upload do
  @moduledoc """
  Below is code from Chris McCord, modified for Cloudflare R2

  https://gist.github.com/chrismccord/37862f1f8b1f5148644b75d20d1cb073

  """
  @one_hour_seconds 3600

  defp config! do
    case IeeeTamuPortal.Features.get_config(:s3_resume_upload) do
      {:ok, config} -> config
      :error -> raise "S3 upload is not configured"
    end
  end

  def bucket_url, do: config!()[:url]

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
    config = config!()
    expires_in = Keyword.get(opts, :expires_in, @one_hour_seconds)

    method = Keyword.fetch!(opts, :method)

    uri = uri(opts)

    url =
      :aws_signature.sign_v4_query_params(
        config[:access_key_id],
        config[:secret_access_key],
        config[:region],
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

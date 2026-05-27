defmodule IeeeTamuPortal.Mautic.Client do
  @moduledoc """
  Low-level HTTP client for the Mautic REST API.

  Uses HTTP Basic Authentication to communicate with Mautic's contact API.
  Configuration is read from application env under `:ieee_tamu_portal, :mautic`.
  """

  require Logger

  @doc """
  Creates or updates a batch of contacts in Mautic.

  Mautic uses email as the dedup key — existing contacts are updated,
  new contacts are created (upsert behavior).

  Returns `{:ok, response_map}` on success, or `{:error, reason}`.
  """
  def create_contacts_batch(contacts) when is_list(contacts) do
    config = config!()
    url = "#{config.base_url}/api/contacts/batch/new"
    auth = Base.encode64("#{config.username}:#{config.password}")

    headers = [
      authorization: "Basic #{auth}",
      accept: "application/json"
    ]

    case Req.post(url, headers: headers, json: contacts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Mautic API error (HTTP #{status}): #{inspect(body)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("Mautic request failed: #{inspect(reason)}")
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Returns the Mautic configuration from application env, or raises if not configured.
  """
  def config! do
    case IeeeTamuPortal.Features.get_config(:mautic) do
      {:ok, config} ->
        config

      :error ->
        raise "Mautic configuration not found. Set :ieee_tamu_portal, :mautic in config."
    end
  end
end

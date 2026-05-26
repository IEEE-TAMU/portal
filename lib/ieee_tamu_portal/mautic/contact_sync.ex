defmodule IeeeTamuPortal.Mautic.ContactSync do
  @moduledoc """
  Business logic for syncing portal members to Mautic contacts.

  Handles member-to-contact transformation, batching, and orchestration
  of full and per-member syncs.
  """

  alias IeeeTamuPortal.{Accounts, Repo}
  alias IeeeTamuPortal.Mautic.Client

  require Logger

  @batch_size 100

  @doc """
  Syncs all members with completed info to Mautic.

  Members without an email or without info are skipped.
  Returns `{:ok, %{success: count, errors: count}}`.
  """
  def sync_all_members do
    Logger.info("Starting full Mautic contact sync")

    members = Accounts.get_all_members_with_info()
    Logger.info("Fetched #{length(members)} members from database")

    {success, errors} = upload_members(members)

    Logger.info("Mautic sync completed: #{success} success, #{errors} errors")
    {:ok, %{success: success, errors: errors}}
  end

  @doc """
  Syncs a single member to Mautic.

  Accepts a member id (integer) or a `%Member{}` struct.
  Does nothing if the member has no email or no info.
  """
  def sync_member(member_id) when is_integer(member_id) do
    member = Accounts.get_member_with_info(member_id)

    case member do
      nil ->
        Logger.warning("Mautic sync skipped: member #{member_id} not found")
        {:ok, :skipped_not_found}

      _ ->
        do_sync_member(member)
    end
  end

  def sync_member(%Accounts.Member{} = member) do
    member = Repo.preload(member, :info)
    do_sync_member(member)
  end

  @doc """
  Transforms a portal `%Member{}` (with preloaded `:info`) into a Mautic contact map.

  Returns `nil` if the member has no email.
  """
  def transform_member_to_contact(%Accounts.Member{} = member) do
    email = member.email

    if is_nil(email) or email == "" do
      nil
    else
      base = %{
        "email" => email,
        "tags" => ["portal-upload"]
      }

      base = maybe_put(base, "confirmed_at", format_datetime(member.confirmed_at))
      base = maybe_put(base, "member_since", format_datetime(member.inserted_at))

      info = member.info

      info =
        case info do
          %Ecto.Association.NotLoaded{} -> nil
          _ -> info
        end

      enrich_with_info(info, base)
    end
  end

  # Private helpers

  defp do_sync_member(member) do
    contact = transform_member_to_contact(member)

    if is_nil(contact) do
      Logger.warning("Mautic sync skipped member #{member.id}: no email")
      {:ok, :skipped_no_email}
    else
      case Client.create_contacts_batch([contact]) do
        {:ok, _response} ->
          Logger.info("Mautic sync success for member #{member.id} (#{member.email})")
          {:ok, :synced}

        {:error, reason} ->
          Logger.error("Mautic sync failed for member #{member.id}: #{reason}")
          {:error, reason}
      end
    end
  end

  defp enrich_with_info(nil, base), do: base

  defp enrich_with_info(info, base) do
    base
    |> maybe_put("firstname", info.preferred_name || info.first_name)
    |> maybe_put("lastname", info.last_name)
    |> maybe_put("major", info.major && to_string(info.major))
    |> maybe_put("graduation_year", info.graduation_year && to_string(info.graduation_year))
    |> maybe_put("tshirt_size", info.tshirt_size && to_string(info.tshirt_size))
    |> maybe_put("uin", info.uin && to_string(info.uin))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = dt) do
    dt |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  defp upload_members(members) do
    contacts =
      members
      |> Enum.map(&transform_member_to_contact/1)
      |> Enum.reject(&is_nil/1)

    total = length(contacts)
    Logger.info("Uploading #{total} contacts to Mautic in batches of #{@batch_size}")

    {success, errors} =
      contacts
      |> Enum.chunk_every(@batch_size)
      |> Enum.reduce({0, 0}, fn batch, {s, e} ->
        case Client.create_contacts_batch(batch) do
          {:ok, _body} ->
            Logger.info("Batch uploaded: #{length(batch)} contacts")
            {s + length(batch), e}

          {:error, reason} ->
            Logger.error("Batch upload failed: #{reason}")
            {s, e + length(batch)}
        end
      end)

    {success, errors}
  end
end

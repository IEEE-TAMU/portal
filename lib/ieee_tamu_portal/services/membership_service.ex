defmodule IeeeTamuPortal.Services.MembershipService do
  @moduledoc """
  Service layer for managing member operations.

  This service orchestrates complex member operations that involve multiple contexts
  and provides a clean API for the web layer to interact with member functionality.
  """

  alias IeeeTamuPortal.{Accounts, Members}

  @doc """
  Updates existing member info or creates new member info if none exists.

  This provides a single interface for member info management regardless of
  whether the member has existing info or not.

  ## Parameters

  - `member` - The member struct (with or without preloaded info)
  - `info_params` - Map of info attributes to create/update

  ## Examples

      iex> update_or_create_member_info(member, %{first_name: "John"})
      {:ok, %Info{}}
      
      iex> update_or_create_member_info(member, %{uin: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def update_or_create_member_info(member, info_params) do
    # Ensure member info is loaded
    member =
      if Ecto.assoc_loaded?(member.info), do: member, else: Accounts.preload_member_info(member)

    case member.info do
      %Members.Info{} = info ->
        Members.update_member_info(info, info_params)

      nil ->
        Members.create_member_info(member, info_params)
    end
  end

  @doc """
  Gets the payment status for a member in a specific year.

  Returns a map with payment status information including whether the member
  has paid and whether they have a payment override.

  ## Parameters

  - `member` - The member struct
  - `year` - The registration year to check

  ## Returns

  A map with the following keys:
  - `:has_paid` - Boolean indicating if member has paid (override or actual payment)
  - `:has_override` - Boolean indicating if payment is via override

  ## Examples

      iex> get_member_payment_status(member, 2024)
      %{has_paid: true, has_override: false}
  """
  def get_member_payment_status(member, year) do
    case Members.get_registration(member.id, year) do
      nil ->
        %{has_paid: false, has_override: false}

      registration ->
        has_paid = registration.payment_override || registration.payment != nil

        %{
          has_paid: has_paid,
          has_override: registration.payment_override
        }
    end
  end

  @doc """
  Updates a member's payment status for a specific year.

  This function handles payment status changes and triggers any necessary
  side effects (like Discord role synchronization).

  ## Parameters

  - `member` - The member struct
  - `year` - The registration year
  - `action` - The action to perform (currently supports `:toggle_override`)

  ## Examples

      iex> update_member_payment_status(member, 2024, :toggle_override)
      {:ok, %Registration{}}
  """
  def update_member_payment_status(member, year, :toggle_override) do
    case Members.toggle_payment_override(member, year) do
      {:ok, registration} ->
        # Trigger side effects
        notify_payment_status_changed(member, registration)
        {:ok, registration}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Private function to handle side effects of payment status changes
  defp notify_payment_status_changed(member, _registration) do
    # For now, directly call Discord sync. In the future, this could use events.
    IeeeTamuPortal.Discord.RoleSyncService.sync_member(member)
  end
end

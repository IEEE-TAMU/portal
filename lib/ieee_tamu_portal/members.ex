defmodule IeeeTamuPortal.Members do
  @moduledoc """
  The Members context.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Members.Info

  ## Database getters

  @doc """
  Gets a member info by member id.

  ## Examples

      iex> get_info_by_member_id(123)
      %Info{}

      iex> get_info_by_member_id(456)
      nil

  """
  def get_info_by_member_id(member_id) when is_integer(member_id) do
    Repo.get_by(Info, member_id: member_id)
  end

  def get_info_by_uin(uin) when is_integer(uin) do
    Repo.get_by(Info, uin: uin)
  end

  ## Changesets

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member info.

  ## Examples

      iex> change_member_info(info)
      %Ecto.Changeset{data: %Info{}}

  """
  def change_member_info(info, attrs \\ %{}) do
    Info.changeset(info, attrs)
  end

  @doc """
  Updates the member info.

  ## Examples

      iex> update_member_info(info, attrs)
      {:ok, %Info{}}

      iex> update_member_info(info, %{})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_info(info, attrs) do
    info
    |> Info.changeset(attrs)
    |> Repo.update()
  end

  def create_member_info(member, attrs) do
    %Info{member_id: member.id}
    |> Info.changeset(attrs)
    |> Repo.insert()
  end
end

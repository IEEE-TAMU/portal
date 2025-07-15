defmodule IeeeTamuPortal.Members do
  @moduledoc """
  The Members context.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Members.{Info, Resume}

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

  @doc """
  Gets a member resume by member ID.

  Returns the resume struct if the member has uploaded one, nil otherwise.

  ## Parameters

    * `member_id` - The integer ID of the member

  ## Examples

      iex> get_resume_by_member_id(123)
      %Resume{original_filename: "john_doe_resume.pdf", ...}

      iex> get_resume_by_member_id(456)
      nil

  """
  def get_resume_by_member_id(member_id) when is_integer(member_id) do
    Repo.get_by(Resume, member_id: member_id)
  end

  ## Changesets

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member info.

  ## Examples

      iex> change_member_info(info)
      %Ecto.Changeset{data: %Info{}}

  """
  def change_member_info(info, attrs \\ %{}) do
    info = info || %Info{}
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

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member resume.

  ## Examples

      iex> change_member_resume(resume)
      %Ecto.Changeset{data: %Resume{}}

  """
  def change_member_resume(resume, attrs \\ %{}) do
    resume = resume || %Resume{}
    Resume.changeset(resume, attrs)
  end

  @doc """
  Updates the member resume.

  ## Examples

      iex> update_member_resume(resume, attrs)
      {:ok, %Resume{}}

      iex> update_member_resume(resume, %{})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_resume(resume, attrs) do
    resume
    |> Resume.changeset(attrs)
    |> Repo.update()
  end

  def create_member_resume(member, attrs) do
    %Resume{member_id: member.id}
    |> Resume.changeset(attrs)
    |> Repo.insert()
  end
end

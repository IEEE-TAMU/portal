defmodule IeeeTamuPortal.Api do
  @moduledoc """
  The Api context.

  This module provides functions for managing API keys used to authenticate
  external requests to the IEEE TAMU Portal API. API keys can be created
  for different contexts (admin, member, etc.) and can be activated or
  deactivated as needed.

  API keys are generated with a secure token and stored with only a hash
  in the database. The plain token is only returned once during creation.

  ## Examples

      iex> Api.list_api_keys()
      [%ApiKey{name: "External Service", context: :admin}, ...]

      iex> Api.create_admin_api_key(%{name: "New Service"})
      {:ok, {"plain_token_here", %ApiKey{}}}
  """

  import Ecto.Query
  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Api.ApiKey

  ## API Keys

  @doc """
  Lists all API keys ordered by creation date (newest first).

  Returns all API keys in the system, which can be used for administrative
  purposes to see what external services have access.

  ## Examples

      iex> list_api_keys()
      [%ApiKey{name: "Service A"}, %ApiKey{name: "Service B"}]

  """
  def list_api_keys do
    Repo.all(from k in ApiKey, order_by: [desc: k.inserted_at])
  end

  @doc """
  Gets a single API key by ID.

  Raises `Ecto.NoResultsError` if the API key does not exist.

  ## Examples

      iex> get_api_key!(123)
      %ApiKey{id: 123, name: "Service A"}

      iex> get_api_key!(999)
      ** (Ecto.NoResultsError)

  """
  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  @doc """
  Creates a general API key with the given attributes.

  This function generates a secure API token and returns both the plaintext
  token and the API key record. The plaintext token is only returned once
  and should be stored securely by the client, as only a hash is persisted
  in the database.

  ## Parameters

  - `attrs`: Map containing API key attributes like `name` and `description`

  ## Examples

      iex> create_api_key(%{name: "My API Key"})
      {:ok, {"generated_token_string", %ApiKey{name: "My API Key"}}}

      iex> create_api_key(%{name: ""})
      {:error, %Ecto.Changeset{}}

  ## Returns

  - `{:ok, {token, api_key}}` on success, where `token` is the plaintext token
  - `{:error, changeset}` on validation failure
  """
  def create_api_key(attrs \\ %{}) do
    {plain_token, changeset} = ApiKey.build_api_key(attrs)

    case Repo.insert(changeset) do
      {:ok, api_key} -> {:ok, {plain_token, api_key}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Creates an admin API key with the given attributes.

  This function generates a secure API token for administrative use and returns
  both the plaintext token and the API key record. The plaintext token is only
  returned once and should be stored securely by the client.

  Admin API keys have elevated privileges and can perform administrative
  operations through the API.

  ## Parameters

  - `attrs`: Map containing API key attributes like `name` and `description`

  ## Examples

      iex> create_admin_api_key(%{name: "Admin Dashboard"})
      {:ok, {"generated_admin_token", %ApiKey{name: "Admin Dashboard", context: :admin}}}

      iex> create_admin_api_key(%{name: ""})
      {:error, %Ecto.Changeset{}}

  ## Returns

  - `{:ok, {token, api_key}}` on success, where `token` is the plaintext token
  - `{:error, changeset}` on validation failure
  """
  def create_admin_api_key(attrs \\ %{}) do
    attrs_with_context = Map.put(attrs, "context", "admin")
    create_api_key(attrs_with_context)
  end

  @doc """
  Updates an existing API key with the given attributes.

  This function allows updating API key metadata like name and description.
  The token hash and context cannot be modified after creation for security
  reasons.

  ## Parameters

  - `api_key`: The existing API key struct to update
  - `attrs`: Map containing the attributes to update

  ## Examples

      iex> update_api_key(api_key, %{name: "Updated Service Name"})
      {:ok, %ApiKey{name: "Updated Service Name"}}

      iex> update_api_key(api_key, %{name: ""})
      {:error, %Ecto.Changeset{}}

  ## Returns

  - `{:ok, api_key}` on successful update
  - `{:error, changeset}` on validation failure
  """
  def update_api_key(%ApiKey{} = api_key, attrs) do
    api_key
    |> ApiKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an API key from the system.

  Once deleted, the API key can no longer be used for authentication.
  This operation cannot be undone, so API keys should only be deleted
  when they are no longer needed or have been compromised.

  ## Parameters

  - `api_key`: The API key struct to delete

  ## Examples

      iex> delete_api_key(api_key)
      {:ok, %ApiKey{}}

      iex> delete_api_key(invalid_api_key)
      {:error, %Ecto.Changeset{}}

  ## Returns

  - `{:ok, api_key}` on successful deletion
  - `{:error, changeset}` if deletion fails
  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking API key changes.

  This function is useful for generating forms or tracking changes
  to an API key without actually persisting them to the database.

  ## Parameters

  - `api_key`: The API key struct to track changes for
  - `attrs`: Optional map of attributes to pre-populate the changeset

  ## Examples

      iex> change_api_key(api_key)
      %Ecto.Changeset{data: %ApiKey{}}

      iex> change_api_key(api_key, %{name: "New Name"})
      %Ecto.Changeset{data: %ApiKey{}, changes: %{name: "New Name"}}

  ## Returns

  An `Ecto.Changeset` struct for the API key
  """
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end

  @doc """
  Verifies an API token and returns the corresponding API key if valid.

  This function takes a plaintext API token, hashes it, and looks up
  the corresponding API key in the database. If found, it updates the
  last_used_at timestamp and returns the API key. This is used for
  API authentication middleware.

  ## Parameters

  - `token`: The plaintext API token to verify

  ## Examples

      iex> verify_api_token("portal_api_abc123def456")
      {:ok, %ApiKey{name: "Service A", context: :admin}}

      iex> verify_api_token("invalid_token")
      {:error, :invalid_token}

      iex> verify_api_token(nil)
      {:error, :invalid_token}

  ## Returns

  - `{:ok, api_key}` if the token is valid and active
  - `{:error, :invalid_token}` if the token is invalid or expired
  """
  def verify_api_token(token) when is_binary(token) do
    case Repo.one(ApiKey.verify_token(token)) do
      %ApiKey{} = api_key ->
        # Update last_used_at timestamp
        api_key
        |> ApiKey.touch_last_used()
        |> Repo.update()

        {:ok, api_key}

      nil ->
        {:error, :invalid_token}
    end
  end
end

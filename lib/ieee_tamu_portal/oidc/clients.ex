defmodule IeeeTamuPortal.OIDC.Clients do
  @moduledoc """
  Database-backed OIDC client management.

  Client secrets are generated once, returned to the caller, and stored only as
  SHA-256 hashes. The plaintext secret is never persisted.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias IeeeTamuPortal.Accounts.Member
  alias IeeeTamuPortal.OIDC
  alias IeeeTamuPortal.OIDC.Client
  alias IeeeTamuPortal.Repo

  def list_clients do
    Repo.all(from c in Client, order_by: [asc: c.name])
  end

  def get_client(id), do: Repo.get(Client, id)
  def get_client!(id), do: Repo.get!(Client, id)

  def get_by_client_id(client_id) when is_binary(client_id) do
    Repo.get_by(Client, client_id: client_id)
  end

  def get_by_client_id(_), do: nil

  def get_enabled_by_client_id(client_id) when is_binary(client_id) do
    Repo.one(from c in Client, where: c.client_id == ^client_id and c.enabled == true)
  end

  def get_enabled_by_client_id(_), do: nil

  def create_client(attrs, %Member{} = created_by) do
    attrs
    |> Map.put("created_by_id", created_by.id)
    |> create_client()
  end

  def create_client(attrs) do
    secret = generate_client_secret()

    with {:ok, client} <- create_client_with_secret(attrs, secret) do
      {:ok, {client, secret}}
    end
  end

  @doc false
  def create_client_with_secret(attrs, secret) when is_binary(secret) do
    attrs = normalize_attrs(attrs)

    %Client{}
    |> Client.changeset(attrs)
    |> put_change(:client_secret_hash, hash_secret(secret))
    |> put_change(:secret_prefix, String.slice(secret, 0, 16))
    |> Repo.insert()
  end

  def update_client(%Client{} = client, attrs) do
    client
    |> Client.update_changeset(attrs)
    |> Repo.update()
  end

  def rotate_secret(%Client{} = client) do
    secret = generate_client_secret()

    changeset =
      change(client,
        client_secret_hash: hash_secret(secret),
        secret_prefix: String.slice(secret, 0, 16)
      )

    with {:ok, client} <- Repo.update(changeset) do
      {:ok, {client, secret}}
    end
  end

  def delete_client(%Client{} = client), do: Repo.delete(client)

  def authenticate(client, secret) when is_binary(secret) do
    expected = Map.get(client, :client_secret_hash)
    is_binary(expected) and Plug.Crypto.secure_compare(expected, hash_secret(secret))
  end

  def authenticate(_, _), do: false

  def mark_used(%Client{} = client) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if is_nil(client.last_used_at) or DateTime.diff(now, client.last_used_at) >= 60 do
      client
      |> change(last_used_at: now)
      |> Repo.update()
    else
      {:ok, client}
    end
  end

  def mark_used_by_client_id(client_id) when is_binary(client_id) do
    case get_by_client_id(client_id) do
      nil -> :ok
      client -> mark_used(client)
    end
  end

  def mark_used_by_client_id(_), do: :ok

  def redirect_uris(%Client{} = client), do: Client.parse_redirect_uris(client.redirect_uris)

  def redirect_uris(client) when is_map(client) do
    client
    |> Map.get(:redirect_uris)
    |> Client.parse_redirect_uris()
  end

  def scopes(%Client{} = client), do: Client.parse_scopes(client.scopes)

  def scopes(client) when is_map(client) do
    case Client.parse_scopes(Map.get(client, :scopes)) do
      [] -> OIDC.scopes()
      scopes -> scopes
    end
  end

  def client_id(client) when is_map(client), do: Map.get(client, :client_id)
  def name(client) when is_map(client), do: Map.get(client, :name) || client_id(client)

  defp normalize_attrs(attrs) do
    client_id =
      attrs
      |> Map.get("client_id", "")
      |> to_string()
      |> String.trim()

    client_id = if client_id == "", do: generate_client_id(), else: client_id
    Map.put(attrs, "client_id", client_id)
  end

  defp hash_secret(secret), do: :crypto.hash(:sha256, secret)

  defp generate_client_id do
    "oidc_" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end

  defp generate_client_secret do
    "oidc_secret_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end
end

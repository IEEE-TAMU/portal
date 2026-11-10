defmodule IeeeTamuPortal.OIDC.Client do
  use Ecto.Schema
  import Ecto.Changeset

  alias IeeeTamuPortal.OIDC

  schema "oidc_clients" do
    field :name, :string
    field :client_id, :string
    field :client_secret_hash, :binary, redact: true
    field :secret_prefix, :string
    field :redirect_uris, :string
    field :scopes, :string, default: "openid profile email role"
    field :enabled, :boolean, default: true
    field :last_used_at, :utc_datetime

    belongs_to :created_by, IeeeTamuPortal.Accounts.Member

    timestamps(type: :utc_datetime)
  end

  @client_id_format ~r/^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$/

  def change_client(client, attrs \\ %{}) do
    cast(client, attrs, [:name, :client_id, :redirect_uris, :scopes, :enabled, :created_by_id])
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :client_id, :redirect_uris, :scopes, :enabled, :created_by_id])
    |> validate_required([:name, :client_id, :redirect_uris, :scopes])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_format(:client_id, @client_id_format,
      message:
        "must be 3-64 characters and contain only letters, numbers, dots, dashes, or underscores"
    )
    |> validate_redirect_uris()
    |> validate_scopes()
    |> unique_constraint(:client_id)
  end

  def update_changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :redirect_uris, :scopes, :enabled])
    |> validate_required([:name, :redirect_uris, :scopes])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_redirect_uris()
    |> validate_scopes()
  end

  def parse_redirect_uris(nil), do: []

  def parse_redirect_uris(text) when is_binary(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def parse_redirect_uris(list) when is_list(list) do
    list
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def parse_scopes(nil), do: []

  def parse_scopes(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.uniq()
  end

  def parse_scopes(list) when is_list(list), do: list

  def valid_redirect_uri?(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: "https", host: host, fragment: nil, userinfo: nil}
      when is_binary(host) and host != "" ->
        true

      %URI{scheme: "http", host: host, fragment: nil, userinfo: nil}
      when host in ["localhost", "127.0.0.1", "::1"] ->
        true

      _ ->
        false
    end
  end

  def valid_redirect_uri?(_), do: false

  defp validate_redirect_uris(changeset) do
    uris = parse_redirect_uris(get_field(changeset, :redirect_uris))
    invalid = Enum.reject(uris, &valid_redirect_uri?/1)

    cond do
      uris == [] ->
        add_error(changeset, :redirect_uris, "must include at least one redirect URI")

      invalid != [] ->
        add_error(
          changeset,
          :redirect_uris,
          "contains invalid URIs (use https, or http only for localhost): #{Enum.join(invalid, ", ")}"
        )

      true ->
        changeset
    end
  end

  defp validate_scopes(changeset) do
    scopes = parse_scopes(get_field(changeset, :scopes))

    cond do
      scopes == [] ->
        add_error(changeset, :scopes, "must include at least the openid scope")

      "openid" not in scopes ->
        add_error(changeset, :scopes, "must include the openid scope")

      Enum.any?(scopes, &(&1 not in OIDC.scopes())) ->
        add_error(changeset, :scopes, "contains unsupported scopes")

      true ->
        changeset
    end
  end
end

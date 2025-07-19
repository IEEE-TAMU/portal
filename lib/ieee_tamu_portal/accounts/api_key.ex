defmodule IeeeTamuPortal.Accounts.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  schema "api_keys" do
    field :name, :string
    field :token_hash, :binary
    field :prefix, :string
    field :last_used_at, :utc_datetime
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a new API key with the format "portal_api_{random}"
  Returns {plain_token, changeset_with_hashed_token}
  """
  def build_api_key(attrs \\ %{}) do
    # Generate random token
    random_part = :crypto.strong_rand_bytes(@rand_size) |> Base.url_encode64(padding: false)
    plain_token = "portal_api_#{random_part}"

    # Hash the token for storage
    token_hash = :crypto.hash(@hash_algorithm, plain_token)

    # Extract prefix for easier identification
    prefix = String.slice(plain_token, 0, 20)

    changeset =
      %__MODULE__{}
      |> cast(attrs, [:name])
      |> put_change(:token_hash, token_hash)
      |> put_change(:prefix, prefix)
      |> validate_required([:name, :token_hash, :prefix])
      |> validate_length(:name, min: 1, max: 100)

    {plain_token, changeset}
  end

  @doc """
  Verifies an API token and returns the corresponding API key if valid and active
  """
  def verify_token(token) when is_binary(token) do
    token_hash = :crypto.hash(@hash_algorithm, token)

    from(k in __MODULE__,
      where: k.token_hash == ^token_hash and k.is_active == true,
      select: k
    )
  end

  @doc """
  Updates the last_used_at timestamp for an API key
  """
  def touch_last_used(api_key) do
    api_key
    |> change(%{last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  @doc """
  Changeset for updating API key attributes
  """
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :is_active])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
  end
end

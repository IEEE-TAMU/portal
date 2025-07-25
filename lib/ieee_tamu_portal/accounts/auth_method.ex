defmodule IeeeTamuPortal.Accounts.AuthMethod do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "secondary_auth_methods" do
    field :provider, Ecto.Enum, values: [:discord], primary_key: true
    field :sub, :string
    field :preferred_username, :string
    field :email, :string
    field :email_verified, :boolean, default: false
    # not storing this for now, if needed create a migration to add these fields
    # field :access_token, :string
    # field :refresh_token, :string
    # field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)

    belongs_to :member, IeeeTamuPortal.Accounts.Member, primary_key: true
  end

  @doc false
  def changeset(auth_method, attrs) do
    auth_method
    |> cast(attrs, [:provider, :sub, :preferred_username, :email, :email_verified])
    |> validate_required([:member_id, :provider, :sub])
    |> unique_constraint([:provider, :sub])
  end
end

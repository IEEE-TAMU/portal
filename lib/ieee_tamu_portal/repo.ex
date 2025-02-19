defmodule IeeeTamuPortal.Repo do
  use Ecto.Repo,
    otp_app: :ieee_tamu_portal,
    adapter: Ecto.Adapters.MyXQL
end

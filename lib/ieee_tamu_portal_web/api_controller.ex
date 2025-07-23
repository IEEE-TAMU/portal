defmodule IeeeTamuPortalWeb.ApiController do
  defmacro __using__(opts) do
    admin_only = Keyword.get(opts, :admin_only, false)
    key_required = Keyword.get(opts, :key_required, false)

    quote do
      use IeeeTamuPortalWeb, :api_controller

      Module.register_attribute(__MODULE__, :auth_responses, accumulate: true)

      import IeeeTamuPortalWeb.Auth.ApiAuth, only: [api_auth: 2, admin_only: 2]

      if unquote(key_required or admin_only) do
        use IeeeTamuPortalWeb.Auth.ApiAuth, admin_only: unquote(admin_only)
      end
    end
  end
end

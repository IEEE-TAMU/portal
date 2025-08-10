defmodule IeeeTamuPortalWeb.Api.Spec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server, SecurityScheme}
  alias IeeeTamuPortalWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: to_string(Application.spec(:ieee_tamu_portal, :description)),
        version: to_string(Application.spec(:ieee_tamu_portal, :vsn))
      },
      components: %Components{
        securitySchemes: %{
          IeeeTamuPortalWeb.Auth.ApiAuth.auth_header() => %SecurityScheme{
            type: "http",
            scheme: "bearer"
          }
        }
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router)
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end

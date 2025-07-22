defmodule IeeeTamuPortalWeb.Api do
  defmodule RenderSpec do
    defdelegate init(conn), to: OpenApiSpex.Plug.RenderSpec
    defdelegate call(conn, opts), to: OpenApiSpex.Plug.RenderSpec
  end

  defmodule SwaggerUI do
    defdelegate init(conn), to: OpenApiSpex.Plug.SwaggerUI
    defdelegate call(conn, opts), to: OpenApiSpex.Plug.SwaggerUI
  end
end

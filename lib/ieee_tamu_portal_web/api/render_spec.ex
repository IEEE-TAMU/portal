defmodule IeeeTamuPortalWeb.Api.RenderSpec do
  def init(conn) do
    # dbg(conn)
    OpenApiSpex.Plug.RenderSpec.init(conn)
  end

  def call(conn, opts) do
    # dbg(conn)
    OpenApiSpex.Plug.RenderSpec.call(conn, opts)
  end

  # defdelegate init(conn), to: OpenApiSpex.Plug.RenderSpec
  # defdelegate call(conn, opts), to: OpenApiSpex.Plug.RenderSpec
end

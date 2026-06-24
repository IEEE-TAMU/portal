defmodule IeeeTamuPortalWeb.Api.V1.StatsController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Members.Registration
  alias IeeeTamuPortal.Settings
  alias IeeeTamuPortalWeb.Api.V1.Schemas

  tags ["stats"]

  insecure_operation :index,
    summary: "Get paid member count",
    description:
      "Returns the number of paid members for a given registration year, or the current registration year if unspecified. No authentication required.",
    parameters: [
      %OpenApiSpex.Parameter{
        in: :query,
        name: "year",
        required: false,
        description:
          "Registration year to count paid members for. Defaults to the current registration year setting.",
        schema: %OpenApiSpex.Schema{type: :integer}
      }
    ],
    responses: [
      ok: {"Paid member count", "application/json", Schemas.PaidMembersCountResponse}
    ] do
    fn conn, params ->
      year =
        case params["year"] do
          nil -> Settings.get_registration_year!()
          year_str when is_binary(year_str) -> String.to_integer(year_str)
          year_int when is_integer(year_int) -> year_int
        end

      count = Registration.paid_members_count_for_year(year)

      json(conn, %{count: count, year: year})
    end
  end
end

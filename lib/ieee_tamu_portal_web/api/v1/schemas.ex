defmodule IeeeTamuPortalWeb.Api.V1.Schemas do
  alias OpenApiSpex.Schema

  defmodule UnauthorizedResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      description: "Response for unauthorized access",
      properties: %{
        error: %Schema{
          type: :string,
          example: "Unauthorized: Invalid or missing API token"
        }
      },
      required: [:error]
    })
  end

  defmodule ForbiddenResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      description: "Response for forbidden access",
      properties: %{
        error: %Schema{
          type: :string,
          example: "Forbidden: Admin access required"
        }
      },
      required: [:error]
    })
  end

  defmodule PingResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        message: %Schema{type: :string, example: "pong"}
      },
      required: [:message]
    })
  end

  # defmodule User do
  #   require OpenApiSpex

  #   OpenApiSpex.schema(%{
  #     # The title is optional. It defaults to the last section of the module name.
  #     # So the derived title for MyApp.User is "User".
  #     title: "User",
  #     description: "A user of the app",
  #     type: :object,
  #     properties: %{
  #       id: %Schema{type: :integer, description: "User ID"},
  #       name: %Schema{type: :string, description: "User name", pattern: ~r/[a-zA-Z][a-zA-Z0-9_]+/},
  #       email: %Schema{type: :string, description: "Email address", format: :email},
  #       birthday: %Schema{type: :string, description: "Birth date", format: :date},
  #       inserted_at: %Schema{
  #         type: :string,
  #         description: "Creation timestamp",
  #         format: :"date-time"
  #       },
  #       updated_at: %Schema{type: :string, description: "Update timestamp", format: :"date-time"}
  #     },
  #     required: [:name, :email],
  #     example: %{
  #       "id" => 123,
  #       "name" => "Joe User",
  #       "email" => "joe@gmail.com",
  #       "birthday" => "1970-01-01T12:34:55Z",
  #       "inserted_at" => "2017-09-12T12:34:55Z",
  #       "updated_at" => "2017-09-13T10:11:12Z"
  #     }
  #   })
  # end

  # defmodule UserResponse do
  #   require OpenApiSpex

  #   OpenApiSpex.schema(%{
  #     title: "UserResponse",
  #     description: "Response schema for single user",
  #     type: :object,
  #     properties: %{
  #       data: User
  #     },
  #     example: %{
  #       "data" => %{
  #         "id" => 123,
  #         "name" => "Joe User",
  #         "email" => "joe@gmail.com",
  #         "birthday" => "1970-01-01T12:34:55Z",
  #         "inserted_at" => "2017-09-12T12:34:55Z",
  #         "updated_at" => "2017-09-13T10:11:12Z"
  #       }
  #     }
  #   })
  # end
end

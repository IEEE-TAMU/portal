defmodule IeeeTamuPortalWeb.Api.V1.Schemas do
  alias OpenApiSpex.Schema

  defmodule UnauthorizedResponse do
    require OpenApiSpex

    @default %{error: "Unauthorized: Invalid or missing API token"}

    OpenApiSpex.schema(%{
      type: :object,
      description: "Response for unauthorized access",
      properties: %{
        error: %Schema{
          type: :string,
          example: @default.error
        }
      },
      required: [:error]
    })

    def default do
      @default
    end
  end

  defmodule ForbiddenResponse do
    require OpenApiSpex

    @default %{error: "Forbidden: Admin access required"}

    OpenApiSpex.schema(%{
      type: :object,
      description: "Response for forbidden access",
      properties: %{
        error: %Schema{
          type: :string,
          example: @default.error
        }
      },
      required: [:error]
    })

    def default do
      @default
    end
  end

  defmodule PingResponse do
    require OpenApiSpex

    @default %{message: "pong"}

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        message: %Schema{type: :string, example: @default.message}
      },
      required: [:message]
    })

    def default do
      @default
    end
  end

  defmodule Payment do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the payer"},
        amount: %Schema{type: :number, format: :float, description: "Payment amount"},
        confirmation_code: %Schema{
          type: :string,
          description: "Confirmation code for the payment",
          example: "USER123"
        },
        tshirt_size: %Schema{
          type: :string,
          enum: ~w(S M L XL XXL)a,
          description: "T-shirt size for the member"
        },
        registration_id: %Schema{
          type: :integer,
          description: "ID of the associated membership"
        },
        id: %Schema{
          type: :string,
          description: "Flywire order ID that serves as the unique identifier for the payment"
        }
      },
      required: [:name, :amount, :tshirt_size, :id],
      example: %{
        id: "202507311846543792838986",
        name: "John Doe",
        amount: 0.00,
        confirmation_code: "JDOE153402",
        tshirt_size: "M",
        registration_id: 12345
      }
    })

    def from_struct(struct) do
      %{
        id: struct.id,
        name: struct.name,
        amount: Decimal.to_float(struct.amount),
        confirmation_code: struct.confirmation_code,
        tshirt_size: to_string(struct.tshirt_size),
        registration_id: struct.registration_id
      }
    end
  end

  defmodule PaymentResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :array,
      items: Payment,
      description: "List of payment details for the authenticated user"
    })
  end

  defmodule PaymentNotFoundResponse do
    require OpenApiSpex

    @default %{error: "Payment not found"}

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        error: %Schema{
          type: :string,
          example: @default.error
        }
      },
      required: [:error]
    })

    def default do
      @default
    end
  end

  defmodule NotFoundResponse do
    require OpenApiSpex

    @default %{error: "Not found"}

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        error: %Schema{type: :string, example: @default.error}
      },
      required: [:error]
    })

    def default(message \\ @default.error) do
      %{error: message}
    end
  end

  defmodule DiscordRolesResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, example: true},
        roles: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, example: "1234567890"},
              name: %Schema{type: :string, example: "Member"}
            },
            required: [:id, :name]
          }
        }
      },
      required: [:success, :roles]
    })

    def from_client(%{"success" => success, "roles" => roles}) do
      %{success: success, roles: roles}
    end
  end

  defmodule DiscordRoleManageRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        email: %Schema{type: :string, format: :email},
        role: %Schema{type: :string}
      },
      required: [:email, :role]
    })
  end

  defmodule DiscordRoleManageResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, example: true},
        message: %Schema{type: :string, example: "Role updated"}
      },
      required: [:success]
    })

    def from_client(%{"success" => success} = body) do
      %{success: success, message: Map.get(body, "message")}
    end
  end
end

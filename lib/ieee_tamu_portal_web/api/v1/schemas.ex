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

  defmodule Payment do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the payer"},
        amount: %Schema{type: :number, format: :decimal, description: "Payment amount"},
        confirmation_code: %Schema{
          type: :string,
          description: "Unique confirmation code for the payment",
          example: "USER123"
        },
        tshirt_size: %Schema{
          type: :string,
          enum: ~w(S M L XL XXL)a,
          description: "T-shirt size for the member"
        },
        contact_email: %Schema{
          type: :string,
          format: :email,
          description: "Contact email for the payment"
        },
        registration_id: %Schema{
          type: :integer,
          description: "ID of the associated membership"
        },
        id: %Schema{
          type: :integer,
          description: "Unique identifier for the payment"
        }
      },
      required: [:name, :amount, :confirmation_code, :tshirt_size, :contact_email],
      example: %{
        id: 3,
        name: "John Doe",
        amount: 50.00,
        confirmation_code: "JDOE123",
        tshirt_size: "M",
        contact_email: "jdoe@tamu.edu",
        registration_id: 12345
      }
    })

    def from_struct(struct) do
      %{
        id: struct.id,
        name: struct.name,
        amount: struct.amount,
        confirmation_code: struct.confirmation_code,
        tshirt_size: struct.tshirt_size,
        contact_email: struct.contact_email,
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

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        error: %Schema{
          type: :string,
          example: "Payment not found"
        }
      },
      required: [:error]
    })
  end
end

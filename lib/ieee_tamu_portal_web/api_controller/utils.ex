defmodule IeeeTamuPortalWeb.ApiController.Utils do
  @moduledoc """
  Utility functions for API controllers.
  """

  @doc """
  Transforms changeset errors into a map suitable for JSON API responses.

  Takes an Ecto.Changeset and returns a map where keys are field names
  and values are lists of error messages with interpolated values.

  ## Examples

      iex> changeset = %Ecto.Changeset{errors: [name: {"can't be blank", []}]}
      iex> changeset_errors(changeset)
      %{name: ["can't be blank"]}

      iex> changeset = %Ecto.Changeset{errors: [count: {"must be greater than %{number}", [number: 0]}]}
      iex> changeset_errors(changeset)
      %{count: ["must be greater than 0"]}
  """
  def changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        # Handle complex types that can't be converted to string
        string_value =
          case value do
            value when is_binary(value) or is_atom(value) or is_number(value) ->
              to_string(value)
            _ ->
              inspect(value)
          end
        String.replace(acc, "%{#{key}}", string_value)
      end)
    end)
  end
end

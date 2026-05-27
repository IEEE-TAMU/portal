defmodule IeeeTamuPortal.Features do
  @moduledoc """
  Central registry of optional server features and their configuration requirements.

  Queries `Application.get_env(:ieee_tamu_portal, ...)` at runtime to determine
  which features are available based on configured credentials/keys.
  """

  alias IeeeTamuPortalWeb.Auth.AdminAuth
  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload

  @features [
    %{
      key: :admin_panel,
      name: "Admin Panel",
      config_key: AdminAuth,
      required_keys: [:username, :password]
    },
    %{
      key: :s3_resume_upload,
      name: "Resume Upload",
      config_key: SimpleS3Upload,
      required_keys: [:region, :access_key_id, :secret_access_key, :url]
    },
    %{
      key: :mautic,
      name: "Mautic CRM Sync",
      config_key: :mautic,
      required_keys: [:base_url, :username, :password]
    },
    %{
      key: :discord_bot,
      name: "Discord Bot",
      config_key: :discord_bot_url,
      required_keys: :single
    },
    %{
      key: :discord_oauth,
      name: "Discord OAuth Login",
      config_key: :discord_oauth,
      required_keys: [:client_id, :client_secret]
    },
    %{
      key: :google_oauth,
      name: "Google OAuth Login",
      config_key: :google_oauth,
      required_keys: [:client_id, :client_secret]
    }
  ]

  @doc """
  Returns `true` if all required configuration for the given feature is present and non-nil.
  """
  def enabled?(feature_key) when is_atom(feature_key) do
    case Enum.find(@features, &(&1.key == feature_key)) do
      nil -> false
      feature -> check_configured(feature)
    end
  end

  @doc """
  Returns all known feature definitions with their current enabled status.

      iex> Features.list()
      [%{key: :s3_resume_upload, name: "Resume Upload", enabled: true}, ...]
  """
  def list do
    Enum.map(@features, fn feature ->
      Map.put(feature, :enabled, check_configured(feature))
    end)
  end

  @doc """
  Returns only the features that are currently configured and enabled.
  """
  def configured_features do
    @features
    |> Enum.filter(&check_configured/1)
    |> Enum.map(fn feature -> Map.put(feature, :enabled, true) end)
  end

  @doc """
  Returns `{:ok, config}` with the full configuration for a feature if it is enabled.

  Returns `:error` when the feature is not configured or unknown.

      iex> Features.get_config(:admin_panel)
      {:ok, username: "admin", password: "password"}
  """
  def get_config(feature_key) do
    with feature when not is_nil(feature) <- Enum.find(@features, &(&1.key == feature_key)),
         true <- check_configured(feature),
         config <- Application.get_env(:ieee_tamu_portal, feature.config_key),
         false <- is_nil(config) do
      {:ok, config}
    else
      _ -> :error
    end
  end

  defp check_configured(feature) do
    config = Application.get_env(:ieee_tamu_portal, feature.config_key)

    case feature.required_keys do
      :single ->
        not is_nil(config) and config != ""

      keys when is_list(keys) ->
        is_list(config) and Enum.all?(keys, &(not is_nil(config[&1])))
    end
  end
end

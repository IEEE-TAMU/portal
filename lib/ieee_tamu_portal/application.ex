defmodule IeeeTamuPortal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  alias IeeeTamuPortal.Features

  @impl true
  def start(_type, _args) do
    children =
      [
        IeeeTamuPortalWeb.Telemetry,
        IeeeTamuPortal.Repo,
        {DNSCluster,
         query: Application.get_env(:ieee_tamu_portal, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: IeeeTamuPortal.PubSub},
        # Start a worker by calling: IeeeTamuPortal.Worker.start_link(arg)
        # {IeeeTamuPortal.Worker, arg}
        IeeeTamuPortal.Members.AgeUpdater
      ] ++
        ([
           if(Features.enabled?(:s3_resume_upload), do: IeeeTamuPortal.S3Delete),
           if(Features.enabled?(:discord_bot), do: IeeeTamuPortal.Discord.RoleSyncService),
           if(Features.enabled?(:mautic), do: IeeeTamuPortal.Mautic.SyncService)
         ]
         |> Enum.reject(&is_nil/1)) ++
        [
          # Start to serve requests, typically the last entry
          IeeeTamuPortalWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IeeeTamuPortal.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      promote_configured_admins()
      {:ok, pid}
    end
  end

  # Promote bootstrap admins from ADMIN_EMAILS after the repo is available.
  # The database may not be migrated yet on a first boot, so never let this
  # prevent the application from starting.
  defp promote_configured_admins do
    IeeeTamuPortal.Accounts.sync_admin_emails()
  rescue
    error ->
      Logger.warning("Skipping ADMIN_EMAILS bootstrap: #{Exception.message(error)}")
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IeeeTamuPortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

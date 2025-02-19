defmodule IeeeTamuPortal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IeeeTamuPortalWeb.Telemetry,
      IeeeTamuPortal.Repo,
      {DNSCluster, query: Application.get_env(:ieee_tamu_portal, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: IeeeTamuPortal.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: IeeeTamuPortal.Finch},
      # Start a worker by calling: IeeeTamuPortal.Worker.start_link(arg)
      # {IeeeTamuPortal.Worker, arg},
      # Start to serve requests, typically the last entry
      IeeeTamuPortalWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IeeeTamuPortal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IeeeTamuPortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

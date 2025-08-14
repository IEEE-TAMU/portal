defmodule IeeeTamuPortal.S3Delete do
  use GenServer

  require Logger

  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload

  # Client
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def delete_object(pid, uri) do
    GenServer.cast(pid, {:delete_object, uri})
  end

  # Server
  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:delete_object, uri}, state) do
    {:ok, url} = SimpleS3Upload.sign(method: "DELETE", uri: uri)

    case :httpc.request(:delete, {url, []}, [], []) do
      {:ok, {{_, 204, _}, _, _}} ->
        :ok

      {:ok, {{_, status_code, _}, _, _}} ->
        Logger.error("S3 delete failed with status code: #{status_code} for #{uri}")

      {:error, reason} ->
        Logger.error("S3 delete failed with reason: #{reason}")
    end

    {:noreply, state}
  end
end

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
    # sign/1 either returns {:ok, url} or raises (only when S3 is unconfigured,
    # in which case this GenServer would not have been started).
    {:ok, url} = SimpleS3Upload.sign(method: "DELETE", uri: uri)
    delete_signed_url(url, uri)

    {:noreply, state}
  end

  defp delete_signed_url(url, uri) do
    case Req.delete(url, req_options()) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("Deleted S3 object #{uri}")

      {:ok, %Req.Response{status: status}} ->
        Logger.error("S3 delete failed with status code: #{status} for #{uri}")

      {:error, reason} ->
        Logger.error("S3 delete failed with reason: #{inspect(reason)} for #{uri}")
    end
  end

  # Req options are injectable via application env so tests can stub the HTTP
  # layer with Req.Test instead of hitting the real bucket.
  defp req_options do
    Application.get_env(:ieee_tamu_portal, :s3_delete_req_opts, [])
  end
end

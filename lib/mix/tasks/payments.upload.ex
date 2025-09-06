defmodule Mix.Tasks.Payments.Upload do
  @moduledoc """
  Upload payments from a CSV file through the public API using an admin API key.

  Usage:
      mix payments.upload HOSTNAME API_KEY PATH_TO_CSV [--dry-run] [--concurrency N]

  Examples:
      mix payments.upload https://portal.local $API_KEY data/payments.csv
      mix payments.upload https://portal.local $API_KEY data/payments.csv --dry-run
      mix payments.upload https://portal.local $API_KEY data/payments.csv --concurrency 5

  The CSV must have headers including the required columns:
    id,name,amount,tshirt_size
  Optional columns:
    confirmation_code,registration_id
  """
  use Mix.Task

  @shortdoc "Upload payments from CSV via API"

  @impl true
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args,
        strict: ["dry-run": :boolean, concurrency: :integer],
        aliases: [d: :"dry-run", c: :concurrency]
      )

    case positional do
      [host, api_key, csv_path] ->
        dry_run = Keyword.get(opts, :"dry-run", false)
        concurrency = Keyword.get(opts, :concurrency, 1)

        IO.puts("Starting payment upload (dry_run=#{dry_run}, concurrency=#{concurrency}) ...")

        case IeeeTamuPortalWeb.Utils.PaymentUploader.upload(host, api_key, csv_path,
               dry_run: dry_run,
               concurrency: concurrency
             ) do
          {:ok, summary} ->
            IO.puts("Upload complete: #{inspect(summary)}")

          {:error, reason} ->
            Mix.raise("Upload failed: #{inspect(reason)}")
        end

      _ ->
        Mix.shell().error("Invalid arguments. See `mix help payments.upload`.")
    end
  end
end

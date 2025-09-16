defmodule Mix.Tasks.Discord.Roles.Assign do
  @moduledoc """
  Assign Discord roles based on CSV columns via the public API using an admin API key.

  Usage:
      mix discord.roles.assign HOSTNAME API_KEY PATH_TO_CSV [--dry-run] [--concurrency N]

  Examples:
      mix discord.roles.assign https://portal.local $API_KEY data/roles-matrix.csv
      mix discord.roles.assign https://portal.local $API_KEY data/roles-matrix.csv --dry-run
      mix discord.roles.assign https://portal.local $API_KEY data/roles-matrix.csv --concurrency 5

  CSV format:
    - Header row: each column header is a role name
    - Each cell below a header is an email to receive that role
    - Blank cells and lines starting with '#' are ignored
  """
  use Mix.Task

  @shortdoc "Assign a Discord role to a list of emails via API"

  @impl true
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args,
        strict: ["dry-run": :boolean, concurrency: :integer],
        aliases: [d: :"dry-run", c: :concurrency]
      )

    case positional do
      [host, api_key, path] ->
        dry_run = Keyword.get(opts, :"dry-run", false)
        concurrency = Keyword.get(opts, :concurrency, 1)

        IO.puts(
          "Starting Discord role assignment (matrix CSV, dry_run=#{dry_run}, concurrency=#{concurrency}) ..."
        )

        case IeeeTamuPortalWeb.Utils.DiscordRoleAssigner.assign(host, api_key, path,
               dry_run: dry_run,
               concurrency: concurrency
             ) do
          {:ok, summary} ->
            IO.puts("Assignment complete: #{inspect(summary)}")

          {:error, reason} ->
            Mix.raise("Assignment failed: #{inspect(reason)}")
        end

      _ ->
        Mix.shell().error("Invalid arguments. See `mix help discord.roles.assign`.")
    end
  end
end

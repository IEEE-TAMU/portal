defmodule IeeeTamuPortalWeb.Utils.DiscordRoleAssigner do
  @moduledoc """
  Assign Discord roles to emails based on CSV columns via the public API using an admin API key.

  Input format:
  - CSV: Header row where each column header is a role name. Each cell below a header is an email
    to receive that role. Blank cells or comments (starting with '#') are ignored.

  Options:
  - :dry_run (boolean) - if true, does not perform POST requests
  - :concurrency (pos_integer) - number of concurrent requests (default 1)
  """

  require Logger

  @default_concurrency 1

  @type assign_opts :: [dry_run: boolean(), concurrency: pos_integer()]

  @spec assign(String.t(), String.t(), String.t(), assign_opts) :: {:ok, map()} | {:error, term()}
  def assign(host, api_key, path, opts \\ [])
      when is_binary(host) and is_binary(api_key) and is_binary(path) do
    dry_run = Keyword.get(opts, :dry_run, false)
    concurrency = Keyword.get(opts, :concurrency, @default_concurrency)

    {:ok, _} = Application.ensure_all_started(:req)

    with {:ok, pairs} <- load_pairs(path) do
      unique_pairs = pairs |> Enum.uniq()

      Logger.info(
        "[DiscordRoleAssigner] pairs=#{length(pairs)} unique_pairs=#{length(unique_pairs)} dry_run=#{dry_run}"
      )

      {ok, errors} =
        if dry_run do
          {Enum.map(unique_pairs, fn {e, r} -> {{e, r}, :dry_run} end), []}
        else
          stream =
            unique_pairs
            |> Task.async_stream(
              fn {email, role} -> {{email, role}, add_role(host, api_key, email, role)} end,
              max_concurrency: concurrency,
              timeout: :infinity
            )

          Enum.reduce(stream, {[], []}, fn
            {:ok, {{email, role}, {:ok, _resp}}}, {oks, errs} ->
              {[{{email, role}, :ok} | oks], errs}

            {:ok, {{email, role}, {:error, reason}}}, {oks, errs} ->
              {oks, [{{email, role}, reason} | errs]}

            {:exit, reason}, {oks, errs} ->
              {oks, [{:exit, reason} | errs]}
          end)
        end

      summary = %{
        total_pairs: length(unique_pairs),
        succeeded: Enum.count(ok, fn {_pair, res} -> res in [:ok, :dry_run] end),
        failed: length(errors),
        errors: Enum.reverse(errors)
      }

      log_summary(summary)

      {:ok, summary}
    end
  end

  defp load_pairs(path) do
    case File.read(path) do
      {:ok, content} -> parse_role_matrix(content)
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_role_matrix(content) do
    rows = NimbleCSV.RFC4180.parse_string(content, skip_headers: false)

    case rows do
      [] ->
        {:ok, []}

      [headers | data] ->
        headers = Enum.map(headers, &String.trim/1)

        indices_with_roles =
          headers
          |> Enum.with_index()
          |> Enum.flat_map(fn
            {"", _i} -> []
            {h, i} when is_binary(h) -> [{i, h}]
            {_other, _i} -> []
          end)

        pairs =
          for row <- data,
              {idx, role} <- indices_with_roles,
              email = row |> Enum.at(idx) |> to_string() |> String.trim(),
              email != "",
              not String.starts_with?(email, "#"),
              do: {email, role}

        {:ok, pairs}
    end
  end

  defp add_role(host, api_key, email, role) do
    url = build_url(host, "/api/v1/discord/roles")

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"accept", "application/json"},
      {"content-type", "application/json"}
    ]

    body = %{email: email, role: role}

    case Req.request(method: :post, url: url, headers: headers, json: body) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, {:request_error, reason}}
    end
  end

  defp build_url(host, path) do
    host = String.trim_trailing(host, "/")
    host <> path
  end

  defp log_summary(%{total_pairs: t, succeeded: s, failed: f, errors: errors}) do
    Logger.info("[DiscordRoleAssigner] TotalPairs=#{t} Succeeded=#{s} Failed=#{f}")
    Enum.each(errors, fn err -> Logger.error("[DiscordRoleAssigner] Error: #{inspect(err)}") end)
  end
end

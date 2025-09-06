defmodule IeeeTamuPortalWeb.Utils.PaymentUploader do
  @moduledoc """
  Uploads payment data from a CSV file to the running portal API using only HTTP calls.

  Expected CSV headers (order can vary):
  	id,name,amount,confirmation_code,tshirt_size,registration_id

  Alternate / external header mappings supported:
  	"Associated Order Number" -> id (will also strip an optional leading '#')
  	"Option: confirmation-code" -> confirmation_code
  	"Option: t-shirt-size" -> tshirt_size
  	"Total with Shipping" -> amount

  Required fields (per API schema): id, name, amount, tshirt_size

  Any extra columns will be ignored. Missing optional columns are omitted.

  Example usage (via the Mix task created separately):
  	mix payments.upload https://portal.example.com API_KEY_HERE payments.csv

  Direct module usage:
  	IeeeTamuPortalWeb.Utils.PaymentUploader.upload("https://host", "api_key", "file.csv")
  """

  require Logger
  alias NimbleCSV.RFC4180, as: CSV

  @wanted_fields ~w(id name amount confirmation_code tshirt_size registration_id)a
  @string_fields ~w(id name confirmation_code tshirt_size)a
  @int_fields ~w(registration_id)a
  @float_fields ~w(amount)a

  @default_concurrency 1

  @type upload_opts :: [dry_run: boolean(), concurrency: pos_integer()]

  @doc """
  Upload payments from a CSV file. Returns a summary map.

  Options:
  	* :dry_run (boolean) - if true, does not perform POST creates (still performs existence checks)
  	* :concurrency (pos_integer) - number of concurrent workers (default 1)
  """
  def upload(host, api_key, csv_path, opts \\ []) when is_binary(host) and is_binary(api_key) do
    dry_run = Keyword.get(opts, :dry_run, false)
    concurrency = Keyword.get(opts, :concurrency, @default_concurrency)

    {:ok, _} = Application.ensure_all_started(:req)

    with {:ok, rows} <- load_csv(csv_path),
         {:ok, existing_ids} <- fetch_existing_ids(host, api_key) do
      headers = List.first(rows)
      data_rows = Enum.drop(rows, 1)
      header_index = build_header_index(headers)

      parsed = Enum.map(data_rows, fn row -> {row, build_attrs(row, header_index)} end)

      {with_id, without_id} =
        Enum.split_with(parsed, fn {_row, attrs} -> present?(attrs[:id]) end)

      missing_or_blank = length(without_id)

      existing_conflicts =
        Enum.filter(with_id, fn {_row, attrs} -> MapSet.member?(existing_ids, attrs[:id]) end)

      to_create =
        Enum.reject(with_id, fn {_row, attrs} -> MapSet.member?(existing_ids, attrs[:id]) end)

      Logger.info(
        "[PaymentUploader] csv_rows=#{length(data_rows)} existing_ids=#{MapSet.size(existing_ids)} missing_id_rows=#{missing_or_blank} already_present=#{length(existing_conflicts)} to_create=#{length(to_create)} dry_run=#{dry_run}"
      )

      {created, errors} =
        if dry_run do
          {length(to_create), []}
        else
          stream =
            to_create
            |> Task.async_stream(
              fn {_row, attrs} -> create_payment(host, api_key, attrs) end,
              max_concurrency: concurrency,
              timeout: :infinity
            )

          Enum.reduce(stream, {0, []}, fn
            {:ok, {:created, :ok, _id}}, {c, errs} -> {c + 1, errs}
            {:ok, {:error, reason, attrs}}, {c, errs} -> {c, [{reason, attrs} | errs]}
            {:exit, reason}, {c, errs} -> {c, [{:exit, reason} | errs]}
          end)
        end

      summary = %{
        csv_rows: length(data_rows),
        missing_id_rows: missing_or_blank,
        existing_conflicts: length(existing_conflicts),
        attempted_creates: length(to_create),
        created: created,
        errors: Enum.reverse(errors)
      }

      log_summary(%{
        total: length(data_rows),
        created: created,
        skipped: length(existing_conflicts),
        errors: errors
      })

      {:ok, summary}
    end
  end

  defp load_csv(path) do
    case File.read(path) do
      {:ok, content} ->
        rows = CSV.parse_string(content, skip_headers: false)

        case rows do
          [] -> {:error, :empty_file}
          _ -> {:ok, rows}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_header_index(headers) do
    headers
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {raw, idx}, acc ->
      canon = canonicalize_header(raw)
      Map.put_new(acc, canon, idx)
    end)
  end

  defp canonicalize_header(header) when is_binary(header) do
    case String.downcase(String.trim(header)) do
      "associated order number" -> "id"
      "option: confirmation-code" -> "confirmation_code"
      "option: t-shirt-size" -> "tshirt_size"
      "total with shipping" -> "amount"
      other -> other
    end
  end

  defp canonicalize_header(other), do: other

  # Removed per-row GET strategy in favor of a single index fetch pass.

  defp build_attrs(row, header_index) do
    header_index
    |> Enum.reduce(%{}, fn {col, idx}, acc ->
      if col in Enum.map(@wanted_fields, &to_string/1) do
        val = Enum.at(row, idx)
        Map.put(acc, String.to_atom(col), normalize_field(String.to_atom(col), val))
      else
        acc
      end
    end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp normalize_field(_field, nil), do: nil
  defp normalize_field(_field, ""), do: nil

  defp normalize_field(:id, value) when is_binary(value) do
    val = value |> String.trim() |> String.trim_leading("#")
    if val == "", do: nil, else: val
  end

  defp normalize_field(field, value) when field in @string_fields, do: value

  defp normalize_field(field, value) when field in @int_fields do
    case Integer.parse(value) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp normalize_field(field, value) when field in @float_fields do
    clean = value |> String.replace(",", "") |> String.trim()

    case Float.parse(clean) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp normalize_field(_field, value), do: value

  defp fetch_existing_ids(host, api_key) do
    url = build_url(host, "/api/v1/payments")
    headers = auth_headers(api_key)

    case Req.request(method: :get, url: url, headers: headers) do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        ids =
          body
          |> Enum.map(fn p -> Map.get(p, "id") || Map.get(p, :id) end)
          |> Enum.filter(&present?/1)
          |> MapSet.new()

        {:ok, ids}

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_payment(host, api_key, attrs) do
    url = build_url(host, "/api/v1/payments")
    headers = auth_headers(api_key)

    json_body =
      attrs
      |> Map.take(@wanted_fields)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Req.request(method: :post, url: url, headers: headers, json: json_body) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        {:created, :ok, Map.get(body, "id") || Map.get(body, :id)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:create_failed, status, body}, attrs}

      {:error, reason} ->
        {:error, {:request_error, reason}, attrs}
    end
  end

  defp auth_headers(api_key) do
    [
      {"authorization", "Bearer #{api_key}"},
      {"accept", "application/json"},
      {"content-type", "application/json"}
    ]
  end

  defp build_url(host, path) do
    host = String.trim_trailing(host, "/")
    host <> path
  end

  defp present?(val), do: not is_nil(val) and val != ""

  defp log_summary(%{total: t, created: c, skipped: s, errors: errors}) do
    Logger.info("[PaymentUploader] Total=#{t} Created=#{c} Skipped=#{s} Errors=#{length(errors)}")
    Enum.each(errors, fn err -> Logger.error("[PaymentUploader] Error: #{inspect(err)}") end)
  end
end

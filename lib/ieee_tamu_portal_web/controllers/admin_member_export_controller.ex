defmodule IeeeTamuPortalWeb.AdminMemberExportController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.{Repo, Settings}
  alias IeeeTamuPortal.Accounts.Member
  alias IeeeTamuPortal.Members.Payment
  alias IeeeTamuPortal.Accounts.AuthMethod
  import Ecto.Query
  alias NimbleCSV.RFC4180, as: CSV

  @csv_headers [
    "member_id",
    "email",
    "confirmed_at",
    # info fields
    "uin",
    "first_name",
    "last_name",
    "preferred_name",
    "age",
    "tshirt_size",
    "phone_number",
    "graduation_year",
    "major",
    "major_other",
    "international_student",
    "international_country",
    "gender",
    "gender_other",
    "ieee_membership_number",
    # discord auth
    "discord_sub",
    "discord_username",
    "discord_email",
    "discord_email_verified",
    # google auth
    "google_sub",
    "google_username",
    "google_email",
    "google_email_verified",
    # registration/payment (current year)
    "registration_year",
    "registration_confirmation_code",
    "registration_payment_override",
    "payment_id",
    "payment_amount",
    "payment_tshirt_size",
    "payment_confirmation_code",
    "payment_name"
  ]

  def download(conn, params) do
    current_year = Settings.get_registration_year!()
    export_date = Date.utc_today() |> Date.to_iso8601()
    paid_only? = truthy?(Map.get(params, "paid"))
    prefix = if paid_only?, do: "paid_members", else: "members"

    auth_methods_map =
      from(a in AuthMethod)
      |> Repo.all()
      |> Enum.group_by(& &1.member_id)

    conn =
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=#{prefix}_#{current_year}_#{export_date}.csv"
      )
      |> send_chunked(200)

    with {:ok, conn} <- send_header(conn) do
      base_query =
        from m in Member,
          left_join: i in assoc(m, :info),
          left_join: r in assoc(m, :registrations),
          on: r.year == ^current_year,
          left_join: p in Payment,
          on: p.registration_id == r.id,
          where:
            ^paid_only? == false or
              (not is_nil(r.id) and (r.payment_override == true or not is_nil(p.id))),
          select: {m, i, r, p}

      Repo.transaction(fn ->
        Repo.stream(base_query)
        |> Stream.chunk_every(250)
        |> Enum.reduce_while(conn, fn chunk, conn_acc ->
          rows =
            Enum.map(chunk, fn {m, i, r, p} ->
              auths = Map.get(auth_methods_map, m.id, [])
              discord = Enum.find(auths, &(&1.provider == :discord))
              google = Enum.find(auths, &(&1.provider == :google))

              [
                # account
                m.id,
                m.email,
                m.confirmed_at,
                # member info
                fetch(i, :uin),
                fetch(i, :first_name),
                fetch(i, :last_name),
                fetch(i, :preferred_name),
                fetch(i, :age),
                fetch(i, :tshirt_size),
                fetch(i, :phone_number),
                fetch(i, :graduation_year),
                fetch(i, :major),
                fetch(i, :major_other),
                fetch(i, :international_student),
                fetch(i, :international_country),
                fetch(i, :gender),
                fetch(i, :gender_other),
                fetch(i, :ieee_membership_number),
                # auth methods
                fetch(discord, :sub),
                fetch(discord, :preferred_username),
                fetch(discord, :email),
                fetch(discord, :email_verified),
                fetch(google, :sub),
                fetch(google, :preferred_username),
                fetch(google, :email),
                fetch(google, :email_verified),
                # registration/payment
                fetch(r, :year),
                fetch(r, :confirmation_code),
                fetch(r, :payment_override),
                fetch(p, :id),
                fetch(p, :amount),
                fetch(p, :tshirt_size),
                fetch(p, :confirmation_code),
                fetch(p, :name)
              ]
            end)

          iodata = CSV.dump_to_iodata(rows)

          case chunk(conn_acc, iodata) do
            {:ok, conn_after} -> {:cont, conn_after}
            {:error, _} -> {:halt, conn_acc}
          end
        end)
      end)
    end

    conn
  end

  defp truthy?(val) when is_binary(val), do: String.downcase(val) in ["1", "true", "yes", "on"]
  defp truthy?(val) when is_boolean(val), do: val
  defp truthy?(_), do: false

  defp send_header(conn) do
    CSV.dump_to_iodata([@csv_headers])
    |> then(&chunk(conn, &1))
  end

  # Generic safe fetch for struct/ nil
  defp fetch(nil, _field), do: nil

  defp fetch(struct, field) do
    Map.get(struct, field)
  rescue
    _ -> nil
  end
end

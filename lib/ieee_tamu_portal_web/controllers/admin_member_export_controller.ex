defmodule IeeeTamuPortalWeb.AdminMemberExportController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.{Repo, Settings}
  alias IeeeTamuPortal.Accounts.Member
  alias IeeeTamuPortal.Members.Payment
  import Ecto.Query
  alias NimbleCSV.RFC4180, as: CSV

  @csv_headers [
    "id",
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
    "discord_username"
  ]

  def download(conn, params) do
    current_year = Settings.get_registration_year!()
    export_date = Date.utc_today() |> Date.to_iso8601()
    paid_only? = truthy?(Map.get(params, "paid"))
    prefix = if paid_only?, do: "paid_members", else: "members"

    members =
      from(m in Member,
        left_join: i in assoc(m, :info),
        left_join: r in assoc(m, :registrations),
        on: r.year == ^current_year,
        left_join: p in Payment,
        on: p.registration_id == r.id,
        left_join: a in assoc(m, :secondary_auth_methods),
        where: a.provider == :discord,
        where:
          ^paid_only? == false or
            (not is_nil(r.id) and (r.payment_override == true or not is_nil(p.id))),
        preload: [
          info: i,
          secondary_auth_methods: a
        ],
        select: m
      )
      |> Repo.all()

    rows =
      Enum.map(members, fn member ->
        info = member.info
        discord = Enum.find(member.secondary_auth_methods, &(&1.provider == :discord))

        [
          member.id,
          member.email,
          member.confirmed_at,
          fetch(info, :uin),
          fetch(info, :first_name),
          fetch(info, :last_name),
          fetch(info, :preferred_name),
          fetch(info, :age),
          fetch(info, :tshirt_size),
          fetch(info, :phone_number),
          fetch(info, :graduation_year),
          fetch(info, :major),
          fetch(info, :major_other),
          fetch(info, :international_student),
          fetch(info, :international_country),
          fetch(info, :gender),
          fetch(info, :gender_other),
          fetch(info, :ieee_membership_number),
          fetch(discord, :preferred_username)
        ]
      end)

    csv = CSV.dump_to_iodata([@csv_headers | rows])

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=#{prefix}_#{current_year}_#{export_date}.csv"
    )
    |> send_resp(200, csv)
  end

  defp truthy?(val) when is_binary(val), do: String.downcase(val) in ["1", "true", "yes", "on"]
  defp truthy?(val) when is_boolean(val), do: val
  defp truthy?(_), do: false

  # Generic safe fetch for struct/ nil
  defp fetch(nil, _field), do: nil

  defp fetch(struct, field) do
    Map.get(struct, field)
  rescue
    _ -> nil
  end
end

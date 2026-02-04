# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     IeeeTamuPortal.Repo.insert!(%IeeeTamuPortal.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias IeeeTamuPortal.Accounts
alias IeeeTamuPortal.Members
alias IeeeTamuPortal.Events
alias IeeeTamuPortal.Settings
alias IeeeTamuPortal.Members.EventCheckin

# Helper functions for generating random data
defmodule SeedHelpers do
  @first_names [
    "James",
    "Mary",
    "John",
    "Patricia",
    "Robert",
    "Jennifer",
    "Michael",
    "Linda",
    "William",
    "Elizabeth",
    "David",
    "Barbara",
    "Richard",
    "Susan",
    "Joseph",
    "Jessica",
    "Thomas",
    "Sarah",
    "Christopher",
    "Karen",
    "Charles",
    "Nancy",
    "Daniel",
    "Lisa",
    "Matthew",
    "Betty",
    "Anthony",
    "Helen",
    "Mark",
    "Sandra",
    "Donald",
    "Donna",
    "Steven",
    "Carol",
    "Paul",
    "Ruth",
    "Andrew",
    "Sharon",
    "Joshua",
    "Michelle",
    "Kenneth",
    "Laura",
    "Kevin",
    "Sarah",
    "Brian",
    "Kimberly",
    "George",
    "Deborah",
    "Timothy",
    "Dorothy",
    "Ronald",
    "Lisa",
    "Jason",
    "Nancy",
    "Edward",
    "Karen",
    "Jeffrey",
    "Betty",
    "Ryan",
    "Helen",
    "Jacob",
    "Sandra",
    "Gary",
    "Donna",
    "Nicholas",
    "Carol",
    "Eric",
    "Ruth",
    "Jonathan",
    "Sharon",
    "Stephen",
    "Michelle",
    "Larry",
    "Laura",
    "Justin",
    "Emily",
    "Scott",
    "Kimberly",
    "Brandon",
    "Deborah",
    "Benjamin",
    "Dorothy",
    "Samuel",
    "Amy",
    "Gregory",
    "Angela",
    "Alexander",
    "Ashley",
    "Patrick",
    "Brenda",
    "Frank",
    "Emma",
    "Raymond",
    "Olivia",
    "Jack",
    "Cynthia",
    "Dennis",
    "Marie",
    "Jerry",
    "Janet",
    "Tyler",
    "Catherine",
    "Aaron",
    "Frances",
    "Jose",
    "Christine",
    "Henry",
    "Samantha",
    "Adam",
    "Debra",
    "Douglas",
    "Rachel",
    "Nathan",
    "Carolyn",
    "Peter",
    "Janet",
    "Zachary",
    "Virginia",
    "Kyle",
    "Maria"
  ]

  @last_names [
    "Smith",
    "Johnson",
    "Williams",
    "Brown",
    "Jones",
    "Garcia",
    "Miller",
    "Davis",
    "Rodriguez",
    "Martinez",
    "Hernandez",
    "Lopez",
    "Gonzalez",
    "Wilson",
    "Anderson",
    "Thomas",
    "Taylor",
    "Moore",
    "Jackson",
    "Martin",
    "Lee",
    "Perez",
    "Thompson",
    "White",
    "Harris",
    "Sanchez",
    "Clark",
    "Ramirez",
    "Lewis",
    "Robinson",
    "Walker",
    "Young",
    "Allen",
    "King",
    "Wright",
    "Scott",
    "Torres",
    "Nguyen",
    "Hill",
    "Flores",
    "Green",
    "Adams",
    "Nelson",
    "Baker",
    "Hall",
    "Rivera",
    "Campbell",
    "Mitchell",
    "Carter",
    "Roberts",
    "Gomez",
    "Phillips",
    "Evans",
    "Turner",
    "Diaz",
    "Parker",
    "Cruz",
    "Edwards",
    "Collins",
    "Reyes",
    "Stewart",
    "Morris",
    "Morales",
    "Murphy",
    "Cook",
    "Rogers",
    "Gutierrez",
    "Ortiz",
    "Morgan",
    "Cooper",
    "Peterson",
    "Bailey",
    "Reed",
    "Kelly",
    "Howard",
    "Ramos",
    "Kim",
    "Cox",
    "Ward",
    "Richardson",
    "Watson",
    "Brooks",
    "Chavez",
    "Wood",
    "James",
    "Bennett",
    "Gray",
    "Mendoza",
    "Ruiz",
    "Hughes",
    "Price",
    "Alvarez",
    "Castillo",
    "Sanders",
    "Patel",
    "Myers",
    "Long",
    "Ross",
    "Foster",
    "Jimenez",
    "Powell",
    "Jenkins",
    "Perry",
    "Russell"
  ]

  @majors [
    :ELEN,
    :CPEN,
    :CSCE,
    :ESET,
    :MXET,
    :ENGR,
    :Other
  ]
  @genders [:Male, :Female, :Other]
  @tshirt_sizes [:S, :M, :L, :XL, :XXL]
  @countries [
    "China",
    "India",
    "Mexico",
    "Canada",
    "South Korea",
    "Vietnam",
    "Philippines",
    "Brazil",
    "Japan",
    "Germany",
    "United Kingdom",
    "France",
    "Italy",
    "Spain",
    "Australia",
    "Nigeria",
    "Egypt",
    "Turkey",
    "Iran",
    "Thailand"
  ]

  def random_first_name, do: Enum.random(@first_names)
  def random_last_name, do: Enum.random(@last_names)
  def random_major, do: Enum.random(@majors)
  def random_gender, do: Enum.random(@genders)
  def random_tshirt_size, do: Enum.random(@tshirt_sizes)
  def random_country, do: Enum.random(@countries)

  def random_major_other do
    # Generate 4 random uppercase letters
    letters = Enum.map(1..4, fn _ -> Enum.random(?A..?Z) end)
    List.to_string(letters)
  end

  def random_uin do
    # Generate UIN in format \d\d\d00\d\d\d\d (3 digits + "00" + 4 digits)
    first_three = Enum.random(100..999)
    last_four = Enum.random(1000..9999)
    "#{first_three}00#{last_four}" |> String.to_integer()
  end

  def random_graduation_year, do: Enum.random(2024..2030)
  def random_international_student, do: Enum.random([true, false])

  def generate_email(first_name, last_name) do
    # Generate various email formats with better uniqueness
    base_first = String.downcase(first_name)
    base_last = String.downcase(last_name)
    random_num = Enum.random(10..999)

    case Enum.random(1..5) do
      1 -> "#{base_first}.#{base_last}@tamu.edu"
      2 -> "#{base_first}#{base_last}@tamu.edu"
      3 -> "#{String.slice(base_first, 0, 1)}#{base_last}@tamu.edu"
      4 -> "#{base_first}#{String.slice(base_last, 0, 1)}#{random_num}@tamu.edu"
      5 -> "#{base_first}.#{base_last}#{random_num}@tamu.edu"
    end
  end
end

# seed 2 events
event_params = [
  %{
    "summary" => "Welcome Back Social",
    "description" => "Kick off the semester with fellow IEEE members!",
    "location" => "IEEE Lounge, ENGR Bldg",
    "dtstart" => DateTime.utc_now(),
    "dtend" => DateTime.add(DateTime.utc_now(), 720, :day),
    "rsvp_limit" => 100
  },
  %{
    "summary" => "Tech Talk: AI in Modern Applications",
    "description" => "Explore the impact of AI in today's technology landscape.",
    "location" => "Room 101, ENGR Bldg",
    "dtstart" => DateTime.utc_now(),
    "dtend" => DateTime.add(DateTime.utc_now(), 720, :day),
    "rsvp_limit" => 50
  }
]

{ failed, success } =
  Enum.reduce(event_params, {0, 0}, fn params, {fail_count, success_count} ->
    case Events.create_event(params) do
      {:ok, _event} ->
        IO.puts("✓ Created event: #{params["summary"]}")
        {fail_count, success_count + 1}

      {:error, changeset} ->
        IO.puts("✗ Failed to create event: #{params["summary"]}")
        IO.inspect(changeset.errors)
        {fail_count + 1, success_count}
    end
  end)

IO.puts("\n📊 Event Creation Summary:")
IO.puts("  Success: #{success}")
IO.puts("  Failed: #{failed}")

# start the first event in the list
Settings.set_current_event(event_params |> hd() |> Map.get("summary"))

# Create a test user
case Accounts.register_member(%{
       email: "test@tamu.edu",
       password: "password"
     }) do
  {:ok, member} ->
    # Confirm the member account
    confirmed_member =
      IeeeTamuPortal.Repo.update!(IeeeTamuPortal.Accounts.Member.confirm_changeset(member))

    IO.puts("✓ Created test user: test@tamu.edu with password 'password'")
    IO.puts("  Member ID: #{confirmed_member.id}")

    # Create member info
    case Members.create_member_info(confirmed_member, %{
           first_name: "Caleb",
           last_name: "Norton",
           tshirt_size: :M,
           gender: :Male,
           uin: 574_003_467,
           major: :CPEN,
           graduation_year: 2027,
           international_student: false
         }) do
      {:ok, info} ->
        IO.puts("✓ Created member info for Caleb Norton")
        IO.puts("  UIN: #{info.uin}")
        IO.puts("  Major: #{info.major}")
        IO.puts("  Graduation Year: #{info.graduation_year}")

      {:error, changeset} ->
        IO.puts("✗ Failed to create member info")
        IO.inspect(changeset.errors)
    end

  {:error, changeset} ->
    IO.puts("✗ Failed to create test user")
    IO.inspect(changeset.errors)
end

# Generate 100 random users
IO.puts("\n🚀 Generating 100 random users...")

{created_count, failed_count, unconfirmed_count, confirmed_no_info_count} =
  Enum.reduce(1..100, {0, 0, 0, 0}, fn i, {created, failed, unconfirmed, confirmed_no_info} ->
    first_name = SeedHelpers.random_first_name()
    last_name = SeedHelpers.random_last_name()
    email = SeedHelpers.generate_email(first_name, last_name)

    case Accounts.register_member(%{
           email: email,
           password: "password123"
         }) do
      {:ok, member} ->
        # Randomly decide whether to confirm this member (50% chance)
        should_confirm = rem(i, 2) == 0

        {final_member, status} =
          if should_confirm do
            # Confirm the member account
            confirmed_member =
              IeeeTamuPortal.Repo.update!(
                IeeeTamuPortal.Accounts.Member.confirm_changeset(member)
              )

            {confirmed_member, :confirmed}
          else
            # Leave unconfirmed
            {member, :unconfirmed}
          end

        # If confirmed, randomly decide whether to add member info (50% chance)
        should_add_info = should_confirm && rem(i, 4) < 2

        if should_add_info do
          # Create member info with random data
          is_international = SeedHelpers.random_international_student()
          selected_major = SeedHelpers.random_major()

          member_info_attrs = %{
            first_name: first_name,
            last_name: last_name,
            tshirt_size: SeedHelpers.random_tshirt_size(),
            gender: SeedHelpers.random_gender(),
            uin: SeedHelpers.random_uin(),
            major: selected_major,
            graduation_year: SeedHelpers.random_graduation_year(),
            international_student: is_international
          }

          # Sometimes add a preferred name (30% chance)
          member_info_attrs =
            if rem(i, 10) < 3 do
              preferred_names = [
                "Alex",
                "Sam",
                "Jordan",
                "Casey",
                "Riley",
                "Morgan",
                "Taylor",
                "Jamie",
                "Avery",
                "Quinn"
              ]

              preferred_name = Enum.random(preferred_names)
              Map.put(member_info_attrs, :preferred_name, preferred_name)
            else
              member_info_attrs
            end

          # Add international_country if student is international
          member_info_attrs =
            if is_international do
              Map.put(member_info_attrs, :international_country, SeedHelpers.random_country())
            else
              member_info_attrs
            end

          # Add major_other if major is :Other
          member_info_attrs =
            if selected_major == :Other do
              Map.put(member_info_attrs, :major_other, SeedHelpers.random_major_other())
            else
              member_info_attrs
            end

          case Members.create_member_info(final_member, member_info_attrs) do
            {:ok, _info} ->
              # RSVP and check-in the user to the current event
              # TODO: error handling
              current_event = Events.get_event_by_name!(Settings.get_current_event!()).uid
              Events.create_rsvp(final_member.id, current_event.uid)
              EventCheckin.insert_for_member_id(final_member.id)
              if rem(i, 10) == 0 do
                IO.puts("  ✓ Created #{i}/100 users...")
              end

              {created + 1, failed, unconfirmed, confirmed_no_info}

            {:error, changeset} ->
              IO.puts("  ✗ Failed to create member info for #{first_name} #{last_name}")
              IO.puts("    Email: #{email}")
              IO.puts("    Errors:")

              Enum.each(changeset.errors, fn {field, {message, _}} ->
                IO.puts("      #{field}: #{message}")
              end)

              {created, failed + 1, unconfirmed, confirmed_no_info}
          end
        else
          # User created but either unconfirmed or confirmed without info
          if rem(i, 10) == 0 do
            IO.puts("  ✓ Created #{i}/100 users...")
          end

          case status do
            :unconfirmed -> {created, failed, unconfirmed + 1, confirmed_no_info}
            :confirmed -> {created, failed, unconfirmed, confirmed_no_info + 1}
          end
        end

      {:error, changeset} ->
        IO.puts("  ✗ Failed to create user #{email}")
        IO.puts("    Registration errors:")

        Enum.each(changeset.errors, fn {field, {message, _}} ->
          IO.puts("      #{field}: #{message}")
        end)

        {created, failed + 1, unconfirmed, confirmed_no_info}
    end
  end)



IO.puts("\n📊 Summary:")
IO.puts("  ✓ Successfully created with full info: #{created_count} users")
IO.puts("  📝 Confirmed but no member info: #{confirmed_no_info_count} users")
IO.puts("  ⏳ Unconfirmed accounts: #{unconfirmed_count} users")
IO.puts("  ✗ Failed to create: #{failed_count} users")
IO.puts("  📧 All users have password: 'password123'")

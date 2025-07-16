alias IeeeTamuPortal.{Repo, Settings.Setting}

# Query all settings
settings = Repo.all(Setting)
IO.puts("Total settings: #{length(settings)}")

Enum.each(settings, fn setting ->
  IO.puts("Key: #{setting.key}, Value: #{setting.value}, Description: #{setting.description}")
end)

# Try to get specific settings
registration_year = Repo.get_by(Setting, key: "registration_year")
current_event = Repo.get_by(Setting, key: "current_event")

IO.puts("\nSpecific settings:")
IO.puts("Registration Year: #{registration_year && registration_year.value}")
IO.puts("Current Event: #{current_event && current_event.value}")

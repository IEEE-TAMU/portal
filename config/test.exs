import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ieee_tamu_portal, IeeeTamuPortal.Repo,
  username: "portal",
  password: "portal",
  hostname: "localhost",
  database: "portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ieee_tamu_portal, IeeeTamuPortalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QfIVIh2CAHjOCZ09bmNxiR/NE6SDUouQ0OmXEBC4/kpkil/c0iNKSqpCPVq3suaZ",
  server: false

# In test we don't send emails
config :ieee_tamu_portal, IeeeTamuPortal.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Admin auth configuration for tests
config :ieee_tamu_portal, IeeeTamuPortalWeb.Auth.AdminAuth,
  username: "admin",
  password: "test_password"

# S3 configuration for tests (mock values)
config :ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload,
  region: "us-east-1",
  access_key_id: "test_access_key",
  secret_access_key: "test_secret_key",
  url: "https://test-bucket.s3.amazonaws.com"

config :ieee_tamu_portal,
       :frontend_time_zone,
       "America/Chicago"

import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/ieee_tamu_portal start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :ieee_tamu_portal, IeeeTamuPortalWeb.Endpoint, server: true
end

if config_env() == :prod and System.get_env("NIX_BUILD_ENV") not in ~w(true 1) do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :ieee_tamu_portal, IeeeTamuPortal.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      """

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :ieee_tamu_portal, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :ieee_tamu_portal, IeeeTamuPortalWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :ieee_tamu_portal, IeeeTamuPortalWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :ieee_tamu_portal, IeeeTamuPortalWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer

  mail_host =
    System.get_env("MAIL_HOST") ||
      raise """
      environment variable MAIL_HOST is missing.
      """

  mail_port =
    System.get_env("MAIL_PORT") ||
      raise """
      environment variable MAIL_PORT is missing.
      """

  config :ieee_tamu_portal, IeeeTamuPortal.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: mail_host,
    ssl: false,
    tls: :never,
    auth: :never,
    port: String.to_integer(mail_port)

  config :swoosh, :api_client, false

  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  # ## Cloudflare R2

  bucket =
    System.get_env("R2_BUCKET") ||
      raise """
      environment variable R2_BUCKET is missing.
      """

  account_id =
    System.get_env("CF_ACCOUNT_ID") ||
      raise """
      environment variable CF_ACCOUNT_ID is missing.
      """

  access_key_id =
    System.get_env("R2_BUCKET_KEY_ID") ||
      raise """
      environment variable R2_BUCKET_KEY_ID is missing.
      """

  secret_access_key =
    System.get_env("R2_BUCKET_ACCESS_KEY") ||
      raise """
      environment variable R2_BUCKET_ACCESS_KEY is missing.
      """

  config :ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload,
    region: "auto",
    access_key_id: access_key_id,
    secret_access_key: secret_access_key,
    url: "https://#{bucket}.#{account_id}.r2.cloudflarestorage.com"

  config :ieee_tamu_portal, IeeeTamuPortalWeb.Auth.AdminAuth,
    username:
      System.get_env("ADMIN_USERNAME") ||
        raise("environment variable ADMIN_USERNAME is missing."),
    password:
      System.get_env("ADMIN_PASSWORD") ||
        raise("environment variable ADMIN_PASSWORD is missing.")

  # Discord configuration
  config :ieee_tamu_portal, :discord_oauth,
    client_id:
      System.get_env("DISCORD_CLIENT_ID") ||
        raise("environment variable DISCORD_CLIENT_ID is missing."),
    client_secret:
      System.get_env("DISCORD_CLIENT_SECRET") ||
        raise("environment variable DISCORD_CLIENT_SECRET is missing.")

  # Google OAuth configuration
  config :ieee_tamu_portal, :google_oauth,
    client_id:
      System.get_env("GOOGLE_CLIENT_ID") ||
        raise("environment variable GOOGLE_CLIENT_ID is missing."),
    client_secret:
      System.get_env("GOOGLE_CLIENT_SECRET") ||
        raise("environment variable GOOGLE_CLIENT_SECRET is missing.")

  config :ieee_tamu_portal,
         :discord_bot_url,
         System.get_env("DISCORD_BOT_URL") ||
           raise("environment variable DISCORD_BOT_URL is missing.")

  config :ieee_tamu_portal,
         :frontend_time_zone,
         System.get_env("FRONTEND_TIME_ZONE") || "America/Chicago"
end

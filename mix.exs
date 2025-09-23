defmodule IeeeTamuPortal.MixProject do
  use Mix.Project

  def project do
    [
      app: :ieee_tamu_portal,
      version: "0.1.27",
      elixir: "== 1.18.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      compilers: [:phoenix_live_view] ++ Mix.compilers()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {IeeeTamuPortal.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "== 3.3.2"},
      {:phoenix, "== 1.8.1"},
      {:phoenix_ecto, "== 4.6.5"},
      {:ecto_sql, "== 3.13.2"},
      {:myxql, "== 0.8.0"},
      {:ecto_mysql_extras, "== 0.6.3", only: :dev},
      {:phoenix_html, "== 4.2.1"},
      {:phoenix_live_reload, "== 1.6.1", only: :dev},
      {:phoenix_live_view, "== 1.1.13"},
      {:aws_signature, "== 0.4.0"},
      {:phoenix_live_dashboard, "== 0.8.7"},
      {:esbuild, "== 0.10.0", runtime: Mix.env() == :dev},
      {:tailwind, "== 0.4.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "== 1.19.7"},
      {:gen_smtp, "== 1.3.0", only: :prod},
      {:telemetry_metrics, "== 1.1.0"},
      {:telemetry_poller, "== 1.3.0"},
      {:gettext, "== 0.26.2"},
      {:jason, "== 1.4.4"},
      {:dns_cluster, "== 0.2.0"},
      {:bandit, "== 1.8.0"},
      {:open_api_spex, "== 3.22.0"},
      {:deps_nix, "== 2.5.0", only: :dev},
      {:req, "== 0.5.15"},
      {:assent, "== 0.3.1"},
      {:zstream, "== 0.6.7"},
      {:flop_phoenix, "== 0.25.3"},
      {:lazy_html, "== 0.1.8", only: :test},
      {:mox, "== 1.2.0", only: :test},
      {:igniter, "== 0.6.29", only: [:dev, :test]},
      {:igniter_new, "== 0.5.31", only: :dev},
      {:nimble_csv, "== 1.3.0"},
      {:eqrcode, "== 0.2.1"},
      {:live_debugger, "== 0.4.1", only: [:dev]},
      {:icalendar, "== 1.1.2"},
      {:tzdata, "== 1.1.3"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    base_aliases = [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind ieee_tamu_portal", "esbuild ieee_tamu_portal"],
      "assets.deploy": [
        "tailwind ieee_tamu_portal --minify",
        "esbuild ieee_tamu_portal --minify",
        "phx.digest"
      ],
      fmt: ["format"]
    ]

    if Mix.env() == :dev do
      base_aliases ++
        [
          # deps_nix -  ensure deps.nix is run before cutting a nix based release
          # to update deps.nix with the latest dependencies from mix.lock.
          # if release is made in gh actions - can install nix and fail if deps.nix
          # is not up to date - opening a PR to update it. Or, run a gh action whenever
          # renovate open a PR to update deps.nix in the same PR.

          # renovate runs something like: 'mix deps.update phoenix_live_view'
          # to update the mix lockfile. However, deps_nix requires all dependencies
          # to be fetched before it can run. It also calls out to the nix cli
          # to hash non mix dependencies. Work with upstream to do the hashing
          # in elixir? and only need the one dep being updated?
          # "deps.get": ["deps.get", "deps.nix"],
          # "deps.update": ["deps.update", "deps.get", "deps.nix"]
        ]
    else
      base_aliases
    end
  end
end

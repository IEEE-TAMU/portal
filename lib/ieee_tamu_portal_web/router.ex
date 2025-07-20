defmodule IeeeTamuPortalWeb.Router do
  use IeeeTamuPortalWeb, :router

  import IeeeTamuPortalWeb.Auth.{MemberAuth, AdminAuth}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IeeeTamuPortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_member
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: IeeeTamuPortalWeb.Api.Spec
  end

  scope "/api", IeeeTamuPortalWeb.Api do
    pipe_through :api

    get "/openapi", RenderSpec, []

    scope "/v1", V1 do
      resources "/ping", PingController, only: [:show], singleton: true
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ieee_tamu_portal, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: IeeeTamuPortalWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # routes available to unauthenticated users
  scope "/", IeeeTamuPortalWeb do
    pipe_through [:browser, :redirect_if_member_is_authenticated]

    post "/members/login", MemberSessionController, :create
    get "/", PageController, :home

    live_session :redirect_if_member_is_authenticated,
      on_mount: [{IeeeTamuPortalWeb.Auth.MemberAuth, :redirect_if_member_is_authenticated}] do
      live "/members/register", MemberRegistrationLive, :new
      live "/members/login", MemberLoginLive, :new
      live "/members/reset_password", MemberForgotPasswordLive, :new
      live "/members/reset_password/:token", MemberResetPasswordLive, :edit
    end
  end

  # routes available to authenticated members
  scope "/", IeeeTamuPortalWeb do
    pipe_through [:browser, :require_authenticated_member]

    live_session :require_authenticated_member,
      on_mount: [
        {IeeeTamuPortalWeb.Auth.MemberAuth, :ensure_authenticated},
        {IeeeTamuPortalWeb.Auth.MemberAuth, :ensure_confirmed}
      ] do
      live "/members/settings", MemberSettingsLive, :edit
      live "/members/info", MemberInfoLive, :edit
    end

    get "/members/registration", MemberRegistrationController, :show

    live_session :ensure_info_submitted,
      on_mount: [
        {IeeeTamuPortalWeb.Auth.MemberAuth, :ensure_authenticated},
        {IeeeTamuPortalWeb.Auth.MemberAuth, :ensure_confirmed},
        {IeeeTamuPortalWeb.Auth.MemberAuth, :ensure_info_submitted}
      ] do
      live "/members/resume", MemberResumeLive, :edit
    end
  end

  # routes available to everyone
  scope "/" do
    pipe_through [:browser]

    get "/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
    delete "/members/log_out", IeeeTamuPortalWeb.MemberSessionController, :delete

    live_session :current_member,
      on_mount: [{IeeeTamuPortalWeb.Auth.MemberAuth, :mount_current_member}] do
      live "/members/confirm/:token", MemberConfirmationLive, :edit
      live "/members/confirm", MemberConfirmationInstructionsLive, :new
    end
  end

  # admin routes using basic auth
  scope "/admin", IeeeTamuPortalWeb do
    pipe_through [:browser, :admin_auth]

    live "/", AdminLive, :index
    live "/members", AdminMembersLive, :index
    live "/settings", AdminSettingsLive, :index
    live "/api-keys", AdminApiKeysLive, :index
    get "/download-resumes", AdminResumeZipController, :download
  end
end

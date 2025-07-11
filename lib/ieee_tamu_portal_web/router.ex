defmodule IeeeTamuPortalWeb.Router do
  use IeeeTamuPortalWeb, :router

  import IeeeTamuPortalWeb.{MemberAuth, AdminAuth}

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
  end

  # Other scopes may use custom stacks.
  # scope "/api", IeeeTamuPortalWeb do
  #   pipe_through :api
  # end

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

    live_session :redirect_if_member_is_authenticated,
      on_mount: [{IeeeTamuPortalWeb.MemberAuth, :redirect_if_member_is_authenticated}] do
      live "/members/register", MemberRegistrationLive, :new
      live "/members/login", MemberLoginLive, :new
      live "/members/reset_password", MemberForgotPasswordLive, :new
      live "/members/reset_password/:token", MemberResetPasswordLive, :edit
    end

    post "/members/login", MemberSessionController, :create
    get "/", PageController, :home
  end

  # routes available to authenticated members
  scope "/", IeeeTamuPortalWeb do
    pipe_through [:browser, :require_authenticated_member]

    live_session :require_authenticated_member,
      on_mount: [
        {IeeeTamuPortalWeb.MemberAuth, :ensure_authenticated},
        {IeeeTamuPortalWeb.MemberAuth, :ensure_confirmed}
      ] do
      live "/members/settings", MemberSettingsLive, :edit
      live "/members/info", MemberInfoLive, :edit
    end

    live_session :ensure_info_submitted,
      on_mount: [
        {IeeeTamuPortalWeb.MemberAuth, :ensure_authenticated},
        {IeeeTamuPortalWeb.MemberAuth, :ensure_confirmed},
        {IeeeTamuPortalWeb.MemberAuth, :ensure_info_submitted}
      ] do
      live "/members/resume", MemberResumeLive, :edit
    end
  end

  # routes available to everyone
  scope "/", IeeeTamuPortalWeb do
    pipe_through [:browser]

    delete "/members/log_out", MemberSessionController, :delete

    live_session :current_member,
      on_mount: [{IeeeTamuPortalWeb.MemberAuth, :mount_current_member}] do
      live "/members/confirm/:token", MemberConfirmationLive, :edit
      live "/members/confirm", MemberConfirmationInstructionsLive, :new
    end
  end

  # admin routes using basic auth
  scope "/admin", IeeeTamuPortalWeb do
    pipe_through [:browser, :admin_auth]

    get "/", AdminController, :home
  end
end

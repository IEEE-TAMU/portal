defmodule IeeeTamuPortal.Github.Client do
  @moduledoc """
  Thin client for the GitHub REST API endpoints used to manage organization
  teams.

  Authentication is provided by `IeeeTamuPortal.Github.Auth`, which returns an
  installation access token for the configured GitHub App.
  """

  alias IeeeTamuPortal.Github.Auth

  @default_api_url "https://api.github.com"

  @doc """
  Gets a user's membership in an organization team.

  Returns `{:ok, membership}` for active or pending memberships and
  `{:ok, :not_member}` when the user has no membership.
  """
  def get_team_membership(org, team_slug, username) do
    url = team_membership_url(org, team_slug, username)

    case request(:get, url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:ok, :not_member}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to get team membership: #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Adds or updates a user's membership in an organization team.
  """
  def add_team_member(org, team_slug, username, role \\ "member") do
    url = team_membership_url(org, team_slug, username)

    case request(:put, url, json: %{role: role}) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to add team member: #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes a user's membership from an organization team.

  A missing membership is treated as success.
  """
  def remove_team_member(org, team_slug, username) do
    url = team_membership_url(org, team_slug, username)

    case request(:delete, url) do
      {:ok, %{status: status}} when status in [204, 404] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to remove team member: #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(method, url, opts \\ []) do
    with {:ok, token} <- Auth.token() do
      headers = [
        {"accept", "application/vnd.github+json"},
        {"authorization", "Bearer #{token}"},
        {"x-github-api-version", "2022-11-28"},
        {"user-agent", "ieee-tamu-portal"}
      ]

      Req.request([method: method, url: url, headers: headers] ++ opts ++ req_options())
    end
  end

  defp team_membership_url(org, team_slug, username) do
    "#{api_url()}/orgs/#{org}/teams/#{team_slug}/memberships/#{username}"
  end

  defp api_url do
    Application.get_env(:ieee_tamu_portal, :github_api_url, @default_api_url)
  end

  defp req_options do
    Application.get_env(:ieee_tamu_portal, :github_req_opts, [])
  end
end

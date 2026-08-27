defmodule IeeeTamuPortal.Discord.ClientTest do
  use IeeeTamuPortal.DataCase, async: false

  alias IeeeTamuPortal.Discord.Client

  @bot_url "http://discord-bot.test"

  setup do
    Application.put_env(:ieee_tamu_portal, :discord_bot_url, @bot_url)

    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :discord_bot_req_opts,
      plug: {Req.Test, IeeeTamuPortal.Discord.Client},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :discord_bot_url)
      Application.delete_env(:ieee_tamu_portal, :discord_bot_req_opts)
    end)

    :ok
  end

  describe "get_user_roles/1" do
    test "returns the user data on success" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        Req.Test.json(conn, %{"success" => true, "roles" => [%{"name" => "Member"}]})
      end)

      assert {:ok, %{"success" => true, "roles" => roles}} = Client.get_user_roles("123")
      assert [%{"name" => "Member"}] = roles
    end

    test "returns {:error, :not_in_guild} when the user is not in the guild" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"message" => "User not found in guild"}))
      end)

      assert {:error, :not_in_guild} = Client.get_user_roles("123")
    end

    test "returns {:error, reason} for other HTTP errors" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"message" => "boom"}))
      end)

      assert {:error, "Failed to get roles: 500"} = Client.get_user_roles("123")
    end
  end

  describe "has_role?/2" do
    test "returns {:ok, true} when the user has the role" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        Req.Test.json(conn, %{"success" => true, "roles" => [%{"name" => "Member"}]})
      end)

      assert {:ok, true} = Client.has_role?("123", "Member")
    end

    test "returns {:ok, false} when the user lacks the role" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        Req.Test.json(conn, %{"success" => true, "roles" => []})
      end)

      assert {:ok, false} = Client.has_role?("123", "Member")
    end

    test "propagates {:error, :not_in_guild}" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"message" => "User not found in guild"}))
      end)

      assert {:error, :not_in_guild} = Client.has_role?("123", "Member")
    end
  end
end

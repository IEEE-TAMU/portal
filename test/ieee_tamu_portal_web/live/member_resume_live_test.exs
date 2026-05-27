defmodule IeeeTamuPortalWeb.MemberResumeLiveTest do
  use IeeeTamuPortalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.{Members}
  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload

  @s3_key SimpleS3Upload

  describe "resume page" do
    test "redirects if member is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/members/resume")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if member has not submitted info", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)

      assert {:error, {:redirect, redirect}} = live(conn, ~p"/members/resume")

      assert redirect.to == ~p"/members/info"

      assert %{"error" => "You must submit your information to access the rest of the site."} =
               redirect.flash
    end

    test "renders resume page when S3 is configured", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member)
      conn = log_in_member(conn, member)

      {:ok, _lv, html} = live(conn, ~p"/members/resume")

      assert html =~ "Resume Drop"
      assert html =~ "No resume uploaded"
    end

    test "redirects when S3 is not configured", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member)
      conn = log_in_member(conn, member)

      original = save_s3_config()

      Application.put_env(:ieee_tamu_portal, @s3_key,
        region: nil,
        access_key_id: nil,
        secret_access_key: nil,
        url: nil
      )

      on_exit(fn -> restore_s3_config(original) end)

      {:error, {:redirect, redirect}} = live(conn, ~p"/members/resume")

      assert redirect.to == "/"
      assert %{"error" => "Page not found"} = redirect.flash
    end
  end

  defp create_member_info(member) do
    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: 123_001_234,
        first_name: "Test",
        last_name: "User",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })
  end

  defp save_s3_config do
    Application.get_env(:ieee_tamu_portal, @s3_key)
  end

  defp restore_s3_config(nil) do
    Application.delete_env(:ieee_tamu_portal, @s3_key)
  end

  defp restore_s3_config(value) do
    Application.put_env(:ieee_tamu_portal, @s3_key, value)
  end
end

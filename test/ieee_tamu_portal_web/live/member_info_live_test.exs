defmodule IeeeTamuPortalWeb.MemberInfoLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Members

  describe "unauthenticated" do
    test "redirects if member is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/members/info")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "/members/info" do
    setup %{conn: conn} do
      member = confirmed_member_fixture()
      %{conn: log_in_member(conn, member), member: member}
    end

    test "renders the info form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/members/info")
      assert html =~ "Personal Information"
      assert html =~ "Academic Information"
    end

    test "shows info form fields", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/members/info")

      assert html =~ "First name"
      assert html =~ "Last name"
      assert html =~ "T-shirt size"
      assert html =~ "Gender"
      assert html =~ "UIN"
      assert html =~ "Major"
      assert html =~ "Graduation year"
    end

    test "validates required fields on submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/info")

      result =
        lv
        |> form("#info_form", %{
          "info" => %{
            "first_name" => "",
            "last_name" => "",
            "uin" => "",
            "tshirt_size" => "",
            "graduation_year" => "",
            "major" => "",
            "gender" => ""
          }
        })
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "shows error on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/info")

      result =
        lv
        |> form("#info_form", %{"info" => %{"first_name" => "", "last_name" => ""}})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "updates form state on phx-change validation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/info")

      lv
      |> form("#info_form", %{"info" => %{"first_name" => "Changed"}})
      |> render_change()

      html = render(lv)
      assert html =~ "Changed"
    end

    test "reset form button restores original values", %{conn: conn, member: member} do
      {:ok, _info} =
        Members.create_member_info(member, %{
          uin: 123_001_234,
          first_name: "Original",
          last_name: "User",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      {:ok, lv, _html} = live(conn, ~p"/members/info")

      lv
      |> form("#info_form", %{"info" => %{"first_name" => "Changed"}})
      |> render_change()

      lv |> element("button", "Reset") |> render_click()

      html = render(lv)
      assert html =~ "Original"
    end

    test "shows conditional field when gender is Other", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/info")

      result =
        lv
        |> form("#info_form", %{"info" => %{"gender" => "Other"}})
        |> render_change()

      assert result =~ "Please specify"
    end

    test "shows conditional field when major is Other", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/info")

      result =
        lv
        |> form("#info_form", %{"info" => %{"major" => "Other"}})
        |> render_change()

      assert result =~ "Please specify"
    end

    test "shows international country field when international_student is checked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/info")

      result =
        lv
        |> form("#info_form", %{"info" => %{"international_student" => "true"}})
        |> render_change()

      assert result =~ "Country of origin"
    end
  end
end

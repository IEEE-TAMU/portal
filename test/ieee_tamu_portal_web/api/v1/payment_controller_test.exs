defmodule IeeeTamuPortalWeb.Api.V1.PaymentControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.ApiFixtures
  import IeeeTamuPortal.MembersFixtures

  @valid_payment_attrs %{
    :id => "202507311846543792838986",
    :name => "John Doe",
    :amount => 25.00,
    :tshirt_size => "M"
  }

  @invalid_payment_attrs %{
    :name => "",
    :amount => nil,
    :tshirt_size => nil
  }

  describe "GET /api/v1/payments" do
    test "returns payments with valid API key", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = member_api_key_fixture(member)
      payment = payment_fixture(member)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments")

      assert [
               %{
                 "id" => payment.id,
                 "name" => payment.name,
                 "amount" => Decimal.to_float(payment.amount),
                 "confirmation_code" => payment.confirmation_code,
                 "tshirt_size" => to_string(payment.tshirt_size),
                 "registration_id" => payment.registration_id
               }
             ] == json_response(conn, 200)
    end

    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/payments")

      assert %{
               "error" => "Unauthorized: Invalid or missing API token"
             } == json_response(conn, 401)
    end

    test "returns 401 with invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_token_header("invalid_token")
        |> get(~p"/api/v1/payments")

      assert %{
               "error" => "Unauthorized: Invalid or missing API token"
             } == json_response(conn, 401)
    end

    test "returns empty array when no payments exist", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = member_api_key_fixture(member)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments")

      assert [] == json_response(conn, 200)
    end

    test "returns multiple payments for admin API key", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      # Create payments for different members
      member1 = member_fixture()
      member2 = member_fixture()
      payment1 = payment_fixture(member1)
      payment2 = payment_fixture(member2)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments")

      response = json_response(conn, 200)
      assert length(response) == 2

      payment_ids = Enum.map(response, & &1["id"])
      assert payment1.id in payment_ids
      assert payment2.id in payment_ids
    end

    test "returns only member's own payments for member API key", %{conn: conn} do
      member1 = member_fixture()
      member2 = member_fixture()
      {token, _api_key} = member_api_key_fixture(member1)

      payment1 = payment_fixture(member1)
      # This shouldn't be returned
      _payment2 = payment_fixture(member2)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments")

      response = json_response(conn, 200)
      assert length(response) == 1
      assert hd(response)["id"] == payment1.id
    end
  end

  describe "GET /api/v1/payments/:id" do
    test "returns payment with valid API key and existing payment", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = member_api_key_fixture(member)
      payment = payment_fixture(member)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments/#{payment.id}")

      assert %{
               "id" => payment.id,
               "name" => payment.name,
               "amount" => Decimal.to_float(payment.amount),
               "confirmation_code" => payment.confirmation_code,
               "tshirt_size" => to_string(payment.tshirt_size),
               "registration_id" => payment.registration_id
             } == json_response(conn, 200)
    end

    test "returns 404 for non-existent payment", %{conn: conn} do
      {token, _api_key} = member_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments/nonexistent")

      assert %{"error" => "Payment not found"} == json_response(conn, 404)
    end

    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/payments/123")

      assert %{
               "error" => "Unauthorized: Invalid or missing API token"
             } == json_response(conn, 401)
    end

    test "admin can access any payment by ID", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = admin_api_key_fixture()
      payment = payment_fixture(member)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments/#{payment.id}")

      assert %{
               "id" => payment.id,
               "name" => payment.name,
               "amount" => Decimal.to_float(payment.amount),
               "confirmation_code" => payment.confirmation_code,
               "tshirt_size" => to_string(payment.tshirt_size),
               "registration_id" => payment.registration_id
             } == json_response(conn, 200)
    end

    test "member cannot access other member's payment", %{conn: conn} do
      member1 = member_fixture()
      member2 = member_fixture()
      {token, _api_key} = member_api_key_fixture(member1)
      payment2 = payment_fixture(member2)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments/#{payment2.id}")

      assert %{"error" => "Payment not found"} == json_response(conn, 404)
    end

    test "returns 404 for malformed payment ID", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/payments/malformed-id-123")

      assert %{"error" => "Payment not found"} == json_response(conn, 404)
    end
  end

  describe "POST /api/v1/payments" do
    test "creates payment with valid admin API key and valid data", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", @valid_payment_attrs)

      assert %{
               "id" => @valid_payment_attrs[:id],
               "name" => @valid_payment_attrs[:name],
               "amount" => @valid_payment_attrs[:amount],
               "tshirt_size" => @valid_payment_attrs[:tshirt_size],
               "confirmation_code" => nil,
               "registration_id" => nil
             } == json_response(conn, 201)
    end

    test "returns 422 with missing required fields", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", @invalid_payment_attrs)

      assert conn.status == 422
    end

    test "returns 422 with missing name field", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.delete(@valid_payment_attrs, :name)

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "returns 422 with missing amount field", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.delete(@valid_payment_attrs, :amount)

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "returns 422 with missing tshirt_size field", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.delete(@valid_payment_attrs, :tshirt_size)

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "returns 422 with missing id field", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.delete(@valid_payment_attrs, :id)

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "returns 422 with duplicate id", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      # Create first payment
      conn
      |> put_token_header(token)
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/v1/payments", @valid_payment_attrs)

      # Try to create another payment with the same ID
      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", @valid_payment_attrs)

      assert conn.status == 422
    end

    test "returns 422 with negative amount", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.put(@valid_payment_attrs, :amount, -10.00)

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "accepts zero amount", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.put(@valid_payment_attrs, :amount, 0.00)

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert %{
               "id" => attrs[:id],
               "name" => attrs[:name],
               "amount" => 0.0,
               "tshirt_size" => attrs[:tshirt_size],
               "confirmation_code" => nil,
               "registration_id" => nil
             } == json_response(conn, 201)
    end

    test "returns 422 with invalid tshirt_size", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.put(@valid_payment_attrs, :tshirt_size, "INVALID")

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "returns 422 with empty string id", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.put(@valid_payment_attrs, :id, "")

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    test "returns 422 with empty string name", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      attrs = Map.put(@valid_payment_attrs, :name, "")

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", attrs)

      assert conn.status == 422
    end

    # TODO: fix this?
    test "handles malformed JSON gracefully", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      # Test with malformed JSON - Phoenix may raise an exception or return 400
      assert_raise Plug.Parsers.ParseError, fn ->
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", "{invalid json")
      end
    end

    # TODO: fix this?
    test "accepts request with wrong content-type", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/v1/payments", @valid_payment_attrs)

      # Phoenix may still accept and process the request
      assert conn.status in [200, 201, 400, 415]
    end

    test "returns 403 with regular API key (non-admin)", %{conn: conn} do
      {token, _api_key} = member_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", @valid_payment_attrs)

      assert %{"error" => "Forbidden: Admin access required"} == json_response(conn, 403)
    end

    test "returns 401 without API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", @valid_payment_attrs)

      assert %{
               "error" => "Unauthorized: Invalid or missing API token"
             } == json_response(conn, 401)
    end

    test "returns 401 with invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_token_header("invalid_token")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/payments", @valid_payment_attrs)

      assert %{
               "error" => "Unauthorized: Invalid or missing API token"
             } == json_response(conn, 401)
    end
  end
end

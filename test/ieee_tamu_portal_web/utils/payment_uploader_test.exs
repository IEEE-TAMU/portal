defmodule IeeeTamuPortalWeb.Utils.PaymentUploaderTest do
  use ExUnit.Case, async: false

  alias IeeeTamuPortalWeb.Utils.PaymentUploader

  @host "http://portal.test"

  setup do
    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :payment_uploader_req_opts,
      plug: {Req.Test, PaymentUploader},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :payment_uploader_req_opts)
    end)

    :ok
  end

  defp write_csv(content) do
    path = Path.join(System.tmp_dir!(), "payments-#{System.unique_integer()}.csv")
    File.write!(path, content)

    on_exit(fn -> File.rm(path) end)

    path
  end

  defp stub_existing_ids(ids) do
    Req.Test.expect(PaymentUploader, fn conn ->
      Req.Test.json(conn, ids)
    end)
  end

  test "upload/4 with dry_run parses, dedupes against existing payments, and creates nothing" do
    path =
      write_csv("""
      id,name,amount,confirmation_code,tshirt_size,registration_id
      1,Alice,20.00,CONF1,M,
      2,Bob,20.00,CONF2,L,
      ,NoId,20.00,CONF3,S,
      """)

    stub_existing_ids([%{"id" => "1"}])

    assert {:ok, summary} = PaymentUploader.upload(@host, "key", path, dry_run: true)

    assert summary.csv_rows == 3
    assert summary.missing_id_rows == 1
    assert summary.existing_conflicts == 1
    assert summary.attempted_creates == 1
    # In dry_run the planned creates are still reported in :created.
    assert summary.created == 1
  end

  test "upload/4 creates new payments via the API" do
    path =
      write_csv("""
      id,name,amount,confirmation_code,tshirt_size,registration_id
      1,Alice,"1,020.50",CONF1,M,
      """)

    stub_existing_ids([])

    Req.Test.expect(PaymentUploader, fn conn ->
      assert conn.body_params["id"] == "1"
      assert conn.body_params["name"] == "Alice"
      assert conn.body_params["amount"] == 1020.5
      assert conn.body_params["tshirt_size"] == "M"

      Req.Test.json(conn, %{"id" => "77"})
    end)

    assert {:ok, summary} = PaymentUploader.upload(@host, "key", path)

    assert summary.attempted_creates == 1
    assert summary.created == 1
    assert summary.errors == []
  end

  test "upload/4 supports alternate external headers" do
    path =
      write_csv("""
      Associated Order Number,name,Total with Shipping,Option: confirmation-code,Option: t-shirt-size
      #12,Bob,25.00,CONF9,XL
      """)

    stub_existing_ids([])

    Req.Test.expect(PaymentUploader, fn conn ->
      assert conn.body_params["id"] == "12"
      assert conn.body_params["amount"] == 25.0
      assert conn.body_params["tshirt_size"] == "XL"
      assert conn.body_params["confirmation_code"] == "CONF9"

      Req.Test.json(conn, %{"id" => "78"})
    end)

    assert {:ok, summary} = PaymentUploader.upload(@host, "key", path)
    assert summary.created == 1
  end

  test "upload/4 records per-row failures" do
    path =
      write_csv("""
      id,name,amount,confirmation_code,tshirt_size,registration_id
      1,Alice,20.00,CONF1,M,
      """)

    stub_existing_ids([])

    Req.Test.expect(PaymentUploader, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(422, Jason.encode!(%{"error" => "invalid"}))
    end)

    assert {:ok, summary} = PaymentUploader.upload(@host, "key", path)

    assert summary.created == 0
    assert length(summary.errors) == 1
    assert [{:create_failed, 422, _}, _attrs] = summary.errors |> List.first() |> Tuple.to_list()
  end

  test "upload/4 returns an error when the existing-payments fetch fails" do
    path =
      write_csv("""
      id,name,amount,confirmation_code,tshirt_size,registration_id
      1,Alice,20.00,CONF1,M,
      """)

    Req.Test.expect(PaymentUploader, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "boom"}))
    end)

    assert {:error, {:unexpected_status, 500, _}} = PaymentUploader.upload(@host, "key", path)
  end
end

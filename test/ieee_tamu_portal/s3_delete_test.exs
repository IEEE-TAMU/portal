defmodule IeeeTamuPortal.S3DeleteTest do
  use ExUnit.Case, async: true

  alias IeeeTamuPortal.S3Delete

  describe "delete_object/2" do
    test "casts delete to GenServer without error" do
      pid = Process.whereis(S3Delete)
      S3Delete.delete_object(pid, "test/file.pdf")
      :timer.sleep(10)
      assert Process.alive?(pid)
    end
  end
end

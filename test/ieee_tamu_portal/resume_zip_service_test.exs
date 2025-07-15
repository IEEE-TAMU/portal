defmodule IeeeTamuPortal.ResumeZipServiceTest do
  use ExUnit.Case, async: true

  test "GenServer is running and accessible" do
    # The GenServer should be running as part of the supervision tree
    state = :sys.get_state(IeeeTamuPortal.ResumeZipService)
    assert state.status == :idle
  end

  test "can check if inets is available" do
    # This test ensures that :inets is available
    assert function_exported?(:inets, :start, 0)
  end
end

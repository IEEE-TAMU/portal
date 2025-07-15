#!/usr/bin/env bash
# Test the application with simple environment
export NIX_BUILD_ENV=true

# Check if the application can start without the :inets error
echo "Testing application startup..."
result=$(./_build/prod/rel/ieee_tamu_portal/bin/ieee_tamu_portal eval "
try do
  # Try to start the application
  Application.ensure_all_started(:inets)
  Application.ensure_all_started(:ssl)
  Application.ensure_all_started(:crypto)
  
  # Check if we can start the GenServer  
  {:ok, pid} = GenServer.start_link(IeeeTamuPortal.ResumeZipService, [])
  state = :sys.get_state(pid)
  GenServer.stop(pid)
  
  IO.puts(\"✅ GenServer started successfully with state: #{inspect(state.status)}\")
  IO.puts(\"✅ No :inets errors found!\")
catch
  error -> 
    IO.puts(\"❌ Error: #{inspect(error)}\")
end
" 2>&1)

echo "$result"

# Check if the result contains success message
if echo "$result" | grep -q "✅ GenServer started successfully"; then
    echo "✅ Test passed: Application and GenServer can start without :inets errors"
    exit 0
else
    echo "❌ Test failed: Check the output above"
    exit 1
fi

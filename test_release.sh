#!/usr/bin/env bash
export PHX_SERVER=true
export DATABASE_URL="ecto://portal:portal@localhost/portal_dev"
export SECRET_KEY_BASE="J7pk/dbOQk2yphdnZ4RZRuC8Do2yoWoq4NEPHaoSB7eLMNFZtHg4gCUn50sLyqcO"
export PHX_HOST="localhost"

# Start the application in the background
./_build/prod/rel/ieee_tamu_portal/bin/ieee_tamu_portal start &
APP_PID=$!

# Wait a bit for the app to start
sleep 5

# Check if the application is running
if ps -p $APP_PID > /dev/null; then
    echo "✅ Application started successfully!"
    # Kill the application
    ./_build/prod/rel/ieee_tamu_portal/bin/ieee_tamu_portal stop
    echo "✅ Application stopped successfully!"
else
    echo "❌ Application failed to start"
    exit 1
fi

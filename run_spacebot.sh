#!/bin/bash
# Wrapper to run spacebot within Supervisor (Optional)

if [ "$START_SPACEBOT" = "true" ] || [ -f "/home/nimda/.spacebot/start.signal" ]; then
    echo "Starting Spacebot..."
    exec /home/nimda/spacebot start
else
    echo "Spacebot not enabled (START_SPACEBOT!=true and no start.signal). Skipping."
    # Stay alive to prevent supervisor from restarting it too quickly
    sleep infinity
fi

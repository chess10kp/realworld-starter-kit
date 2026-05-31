#!/bin/bash
set -e

# Port configuration
JAC_PORT=${JAC_PORT:-8000}
ADAPTER_PORT=${PORT:-3000}

echo "🚀 Starting RealWorld Conduit (Jac/Jaseci)"
echo "   Jac server:  port $JAC_PORT"
echo "   Adapter:     port $ADAPTER_PORT"

# Start Jac server
jac start main.jac --dev --no_client --port $JAC_PORT &

# Wait for Jac to be ready
echo "⏳ Waiting for Jac server..."
for i in $(seq 1 120); do
    if curl -sf http://localhost:$JAC_PORT/ > /dev/null 2>&1; then
        echo "✅ Jac server ready (${i}s)"
        break
    fi
    if [ $i -eq 120 ]; then
        echo "❌ Jac server failed to start"
        exit 1
    fi
    sleep 1
done

# Give Jac a moment to fully initialize
sleep 3

# Start adapter
echo "🔧 Starting adapter on port $ADAPTER_PORT..."
python3 adapter.py $ADAPTER_PORT

# Keep alive
wait

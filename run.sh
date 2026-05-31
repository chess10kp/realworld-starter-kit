#!/usr/bin/env bash
# Start the RealWorld Conduit API (Jac backend + adapter)
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== RealWorld Conduit API (Jac) ===${NC}"

# Kill any existing processes
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down...${NC}"
    kill $JAC_PID $ADAPTER_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start Jac backend
echo -e "${GREEN}Starting Jac backend on port 8000...${NC}"
jac start main.jac --dev --no_client --port 8000 &
JAC_PID=$!

# Wait for Jac to be ready
echo -e "${YELLOW}Waiting for Jac backend...${NC}"
for i in $(seq 1 30); do
    if curl -s http://localhost:8000/ > /dev/null 2>&1; then
        echo -e "${GREEN}Jac backend ready!${NC}"
        break
    fi
    sleep 1
done

# Start adapter
echo -e "${GREEN}Starting RealWorld adapter on port 3000...${NC}"
python3 adapter.py 3000 &
ADAPTER_PID=$!

# Wait for adapter to be ready
sleep 1
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} RealWorld Conduit API is running!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  API:     http://localhost:3000/api"
echo "  Jac:     http://localhost:8000"
echo ""
echo "  Try:     curl http://localhost:3000/api/tags"
echo ""

wait

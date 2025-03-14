#!/bin/bash

# Configuration - Replace these with your actual values
PORTAINER_URL="http://localhost:9000"  # e.g., http://localhost:9000
USERNAME="admin"  # e.g., admin
PASSWORD="Wl+jVfl5l3m9tM24"  # Your Portainer password
ENDPOINT_ID=1  # Usually 1 for local Docker; check your Portainer endpoints
STACK_NAME="wordpress-stack"  # Name of the stack to deploy
STACK_FILE="./stacks/monitoring/docker-compose.yml"  # Pabashth to your stack definition file

# Check if required tools are installed
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: This script requires 'curl' and 'jq'. Please install them."
    exit 1
fi

# Check if stack file exists
if [ ! -f "$STACK_FILE" ]; then
    echo "Error: Stack file '$STACK_FILE' not found."
    exit 1
fi

# Step 1: Authenticate and get JWT token
echo "Authenticating to Portainer..."
AUTH_RESPONSE=$(curl -s -X POST "$PORTAINER_URL/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"$USERNAME\",\"Password\":\"$PASSWORD\"}")

# Extract JWT token
JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.jwt')
if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
    echo "Authentication failed: $AUTH_RESPONSE"
    exit 1
fi
echo "Authentication successful! JWT: $JWT_TOKEN"

# Step 2: Read and prepare stack content
echo "Reading stack file: $STACK_FILE"
STACK_CONTENT=$(cat "$STACK_FILE" | sed 's/"/\\"/g' | tr -d '\n\r')
if [ -z "$STACK_CONTENT" ]; then
    echo "Error: Stack file '$STACK_FILE' is empty."
    exit 1
fi

# Step 3: Deploy the stack
echo "Deploying stack '$STACK_NAME' to endpoint $ENDPOINT_ID..."
DEPLOY_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$PORTAINER_URL/api/stacks?type=2&method=string&endpointId=$ENDPOINT_ID" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"Name\":\"$STACK_NAME\",\"StackFileContent\":\"$STACK_CONTENT\",\"Env\":[]}")

# Extract HTTP status code (last 3 characters of response)
HTTP_STATUS=${DEPLOY_RESPONSE: -3}
# Extract response body (everything except the last 3 characters)
RESPONSE_BODY=${DEPLOY_RESPONSE%???}

echo "HTTP Status: $HTTP_STATUS"
echo "Response: $RESPONSE_BODY"

# Check if deployment was successful
if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 201 ]; then
    echo "Stack '$STACK_NAME' deployed successfully!"
else
    echo "Failed to deploy stack: $RESPONSE_BODY (HTTP Status: $HTTP_STATUS)"
    exit 1
fi
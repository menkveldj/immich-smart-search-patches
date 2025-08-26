#!/bin/bash

# Get access token for test user
API_URL="http://localhost:3003/api"
EMAIL="test@example.com"
PASSWORD="TestPassword123!"

# Login and get token
LOGIN_RESPONSE=$(curl -s -X POST "${API_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.accessToken // empty')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Could not get access token"
    echo "$LOGIN_RESPONSE" | jq '.'
    exit 1
fi

# Save to .env.test
cat > .env.test << EOF
ACCESS_TOKEN=${ACCESS_TOKEN}
API_URL=${API_URL}
EMAIL=${EMAIL}
USER_ID=$(echo "$LOGIN_RESPONSE" | jq -r '.userId')
EOF

echo "Access token saved to .env.test"
echo "Token: ${ACCESS_TOKEN:0:20}..."
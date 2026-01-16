#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:3000}"
API_ENDPOINT="${BASE_URL}/claims"

echo -e "${YELLOW}Populating test claims data...${NC}"
echo -e "Target API: ${API_ENDPOINT}\n"

# Function to create a claim
create_claim() {
  local claim_data="$1"
  local claim_id=$(echo "$claim_data" | jq -r '.id')
  
  echo -e "${YELLOW}Creating claim: ${claim_id}${NC}"
  
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$claim_data" \
    "$API_ENDPOINT")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Created claim ${claim_id}${NC}"
  else
    echo -e "${RED}✗ Failed to create claim ${claim_id} (HTTP ${http_code})${NC}"
    echo "$body"
  fi
}

# Sample claims data
claims='[
  {
    "id": "CLM-2001",
    "status": "OPEN",
    "policyNumber": "POL-8001",
    "lastUpdated": "2026-01-15T10:30:00Z",
    "amount": 15000,
    "customerName": "Sarah Williams",
    "adjuster": "Chris Anderson"
  },
  {
    "id": "CLM-2002",
    "status": "PENDING_INFO",
    "policyNumber": "POL-8002",
    "lastUpdated": "2026-01-14T14:20:00Z",
    "amount": 4500,
    "customerName": "Michael Brown",
    "adjuster": "Pat Kelly"
  },
  {
    "id": "CLM-2003",
    "status": "OPEN",
    "policyNumber": "POL-8003",
    "lastUpdated": "2026-01-13T09:15:00Z",
    "amount": 28000,
    "customerName": "Jessica Martinez",
    "adjuster": "Alex Rivera"
  },
  {
    "id": "CLM-2004",
    "status": "CLOSED",
    "policyNumber": "POL-8004",
    "lastUpdated": "2026-01-12T16:45:00Z",
    "amount": 6700,
    "customerName": "David Kim",
    "adjuster": "Sam Taylor"
  },
  {
    "id": "CLM-2005",
    "status": "OPEN",
    "policyNumber": "POL-8005",
    "lastUpdated": "2026-01-11T11:00:00Z",
    "amount": 19500,
    "customerName": "Emily Davis",
    "adjuster": "Jordan Morgan"
  },
  {
    "id": "CLM-2006",
    "status": "PENDING_INFO",
    "policyNumber": "POL-8006",
    "lastUpdated": "2026-01-10T13:30:00Z",
    "amount": 8200,
    "customerName": "Robert Wilson",
    "adjuster": "Chris Anderson"
  },
  {
    "id": "CLM-2007",
    "status": "OPEN",
    "policyNumber": "POL-8007",
    "lastUpdated": "2026-01-09T08:45:00Z",
    "amount": 12300,
    "customerName": "Amanda Lee",
    "adjuster": "Pat Kelly"
  },
  {
    "id": "CLM-2008",
    "status": "DENIED",
    "policyNumber": "POL-8008",
    "lastUpdated": "2026-01-08T15:20:00Z",
    "amount": 3500,
    "customerName": "James Taylor",
    "adjuster": "Alex Rivera"
  },
  {
    "id": "CLM-2009",
    "status": "OPEN",
    "policyNumber": "POL-8009",
    "lastUpdated": "2026-01-07T12:10:00Z",
    "amount": 31000,
    "customerName": "Lisa Anderson",
    "adjuster": "Sam Taylor"
  },
  {
    "id": "CLM-2010",
    "status": "CLOSED",
    "policyNumber": "POL-8010",
    "lastUpdated": "2026-01-06T10:00:00Z",
    "amount": 9800,
    "customerName": "Kevin White",
    "adjuster": "Jordan Morgan"
  }
]'

# Create each claim
echo "$claims" | jq -c '.[]' | while read -r claim; do
  create_claim "$claim"
  sleep 0.2  # Small delay to avoid overwhelming the API
done

echo -e "\n${GREEN}Data population complete!${NC}"
echo -e "\nVerify created claims:"
echo -e "  ${YELLOW}curl ${API_ENDPOINT}/CLM-2001${NC}"
echo -e "  ${YELLOW}curl ${API_ENDPOINT}/CLM-2005${NC}"

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

# Sample claims data with notes
claims='[
  {
    "id": "CLM-2001",
    "status": "OPEN",
    "policyNumber": "POL-8001",
    "lastUpdated": "2026-01-15T10:30:00Z",
    "amount": 15000,
    "customerName": "Sarah Williams",
    "adjuster": "Chris Anderson",
    "notes": [
      "Water damage to kitchen and basement reported on 2026-01-10.",
      "Initial inspection completed; significant damage to flooring and drywall.",
      "Customer provided photos showing extent of water intrusion.",
      "Contractor estimate requested for full restoration.",
      "Pending site visit scheduled for 2026-01-16."
    ]
  },
  {
    "id": "CLM-2002",
    "status": "PENDING_INFO",
    "policyNumber": "POL-8002",
    "lastUpdated": "2026-01-14T14:20:00Z",
    "amount": 4500,
    "customerName": "Michael Brown",
    "adjuster": "Pat Kelly",
    "notes": [
      "Minor vehicle collision; front bumper and headlight damage.",
      "Customer requested rental car coverage; approved for 7 days.",
      "Body shop estimate received: $4,200.",
      "Waiting for customer to drop off vehicle for repairs."
    ]
  },
  {
    "id": "CLM-2003",
    "status": "OPEN",
    "policyNumber": "POL-8003",
    "lastUpdated": "2026-01-13T09:15:00Z",
    "amount": 28000,
    "customerName": "Jessica Martinez",
    "adjuster": "Alex Rivera",
    "notes": [
      "Storm damage to roof; multiple shingles missing.",
      "Emergency tarp installed to prevent further damage.",
      "Roofing contractor provided detailed estimate.",
      "Full roof replacement approved; work scheduled for next week.",
      "Customer very satisfied with quick response."
    ]
  },
  {
    "id": "CLM-2004",
    "status": "CLOSED",
    "policyNumber": "POL-8004",
    "lastUpdated": "2026-01-12T16:45:00Z",
    "amount": 6700,
    "customerName": "David Kim",
    "adjuster": "Sam Taylor",
    "notes": [
      "Small kitchen fire contained by homeowner.",
      "Fire department report obtained; no structural damage.",
      "Smoke damage to cabinets and appliances noted.",
      "Insurance inspection completed; claim approved.",
      "Payment issued on 2026-01-12; claim closed."
    ]
  },
  {
    "id": "CLM-2005",
    "status": "OPEN",
    "policyNumber": "POL-8005",
    "lastUpdated": "2026-01-11T11:00:00Z",
    "amount": 19500,
    "customerName": "Emily Davis",
    "adjuster": "Jordan Morgan",
    "notes": [
      "Major tree fell on house during storm; structural damage to roof and bedroom.",
      "Emergency board-up completed to secure property.",
      "Structural engineer inspection scheduled.",
      "Large loss claim; special handling required.",
      "Mortgage company added as payee for settlement."
    ]
  },
  {
    "id": "CLM-2006",
    "status": "PENDING_INFO",
    "policyNumber": "POL-8006",
    "lastUpdated": "2026-01-10T13:30:00Z",
    "amount": 8200,
    "customerName": "Robert Wilson",
    "adjuster": "Chris Anderson",
    "notes": [
      "Jewelry theft reported; police report filed.",
      "Customer provided receipts for stolen items.",
      "Missing appraisal for diamond ring; requested from jeweler.",
      "Pending receipt of appraisal to finalize claim value.",
      "Estimated value: $8,200."
    ]
  },
  {
    "id": "CLM-2007",
    "status": "OPEN",
    "policyNumber": "POL-8007",
    "lastUpdated": "2026-01-09T08:45:00Z",
    "amount": 12300,
    "customerName": "Amanda Lee",
    "adjuster": "Pat Kelly",
    "notes": [
      "Basement flooding from pipe burst.",
      "Emergency plumber fixed pipe; invoice provided.",
      "Restoration company began water extraction and drying.",
      "Mold inspection scheduled for next week.",
      "Customer staying with family during repairs."
    ]
  },
  {
    "id": "CLM-2008",
    "status": "DENIED",
    "policyNumber": "POL-8008",
    "lastUpdated": "2026-01-08T15:20:00Z",
    "amount": 3500,
    "customerName": "James Taylor",
    "adjuster": "Alex Rivera",
    "notes": [
      "Claim denied: damage occurred before policy inception date.",
      "Policy effective 2026-01-05; damage occurred 2026-01-03.",
      "Reviewed with supervisor; denial upheld.",
      "Denial letter sent to customer on 2026-01-08.",
      "Customer has right to appeal within 30 days."
    ]
  },
  {
    "id": "CLM-2009",
    "status": "OPEN",
    "policyNumber": "POL-8009",
    "lastUpdated": "2026-01-07T12:10:00Z",
    "amount": 31000,
    "customerName": "Lisa Anderson",
    "adjuster": "Sam Taylor",
    "notes": [
      "Commercial property fire; significant damage to warehouse.",
      "Fire marshal investigation ongoing.",
      "Business interruption coverage activated.",
      "Inventory loss assessment in progress.",
      "Forensic accountant engaged to determine financial impact."
    ]
  },
  {
    "id": "CLM-2010",
    "status": "CLOSED",
    "policyNumber": "POL-8010",
    "lastUpdated": "2026-01-06T10:00:00Z",
    "amount": 9800,
    "customerName": "Kevin White",
    "adjuster": "Jordan Morgan",
    "notes": [
      "Auto claim: rear-end collision at traffic light.",
      "Police report confirms other driver at fault.",
      "Subrogation initiated against at-fault party insurance.",
      "Repairs completed; total cost $9,800.",
      "Claim closed; subrogation recovery pending."
    ]
  }
]'

# Create each claim
echo "$claims" | jq -c '.[]' | while read -r claim; do
  create_claim "$claim"
  sleep 0.2  # Small delay to avoid overwhelming the API
done

echo -e "\n${GREEN}Data population complete!${NC}"
echo -e "${GREEN}Created 10 claims with notes automatically uploaded to S3${NC}"
echo -e "\nVerify created claims:"
echo -e "  ${YELLOW}curl ${API_ENDPOINT}/CLM-2001${NC}"
echo -e "  ${YELLOW}curl ${API_ENDPOINT}/CLM-2005${NC}"
echo -e "\nTest summarize endpoint:"
echo -e "  ${YELLOW}curl -X POST ${API_ENDPOINT}/CLM-2001/summarize${NC}"

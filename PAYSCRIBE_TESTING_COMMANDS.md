# PayScribe Sandbox Testing - Curl Commands

## 1. Test Data Vending Endpoint

### ✅ Known Working Format
```bash
# Set variables
PAYSCRIBE_API_KEY="your_api_key_here"
BASE_URL="https://sandbox.payscribe.ng/api/v1"

# Test MTN data vending with local phone number
curl -X POST "${BASE_URL}/data/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "network": "mtn",
    "recipient": "08012345670",
    "plan": "PSPLAN_531",
    "ref": "test-001"
  }' \
  -w "\n\nHTTP Status: %{http_code}\n"
```

### Try With Different Phone Numbers
```bash
# Try different MTN numbers
for phone in "08012345670" "08012345671" "08012345672" "08034567890" "08098765432"; do
  echo "Testing with: $phone"
  curl -X POST "https://sandbox.payscribe.ng/api/v1/data/vend" \
    -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"network\": \"mtn\",
      \"recipient\": \"${phone}\",
      \"plan\": \"PSPLAN_531\",
      \"ref\": \"test-$(date +%s)\"
    }" \
    -s | jq '.'
  echo "---"
done
```

### Try Different Networks
```bash
# Test all networks with different test numbers
networks=(
  "mtn:08012345670"
  "glo:07012345670"
  "airtel:08112345670"
  "9mobile:08092345670"
  "smile:08082345670"
)

for network_data in "${networks[@]}"; do
  IFS=':' read -r network phone <<< "$network_data"
  echo "Testing $network with $phone"
  
  curl -X POST "https://sandbox.payscribe.ng/api/v1/data/vend" \
    -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"network\": \"${network}\",
      \"recipient\": \"${phone}\",
      \"plan\": \"PSPLAN_531\",
      \"ref\": \"test-${network}-$(date +%s)\"
    }" \
    -s | jq '.'
done
```

---

## 2. Test Bill Payment Endpoint

### 🔴 Currently Failing - Try Different Auth Methods

#### Method A: Bearer Token (Currently Used)
```bash
curl -X POST "https://sandbox.payscribe.ng/api/v1/electricity/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "meter_number": "1234567890",
    "meter_type": "postpaid",
    "amount": 5000,
    "service": "ikedc",
    "customer_name": "TEST",
    "phone": "08012345670",
    "ref": "bill-test-001"
  }' \
  -w "\n\nHTTP Status: %{http_code}\n"
```

#### Method B: API Key in Header (Alternative)
```bash
curl -X POST "https://sandbox.payscribe.ng/api/v1/electricity/vend" \
  -H "X-API-Key: ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "meter_number": "1234567890",
    "meter_type": "postpaid",
    "amount": 5000,
    "service": "ikedc",
    "customer_name": "TEST",
    "phone": "08012345670",
    "ref": "bill-test-001"
  }' \
  -w "\n\nHTTP Status: %{http_code}\n"
```

#### Method C: Basic Auth (If Different Key Required)
```bash
# If you have a separate bill payment key
BILL_API_KEY="your_bill_api_key_here"

curl -X POST "https://sandbox.payscribe.ng/api/v1/electricity/vend" \
  -H "Authorization: Bearer ${BILL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "meter_number": "1234567890",
    "meter_type": "postpaid",
    "amount": 5000,
    "service": "ikedc",
    "customer_name": "TEST",
    "phone": "08012345670",
    "ref": "bill-test-001"
  }' \
  -w "\n\nHTTP Status: %{http_code}\n"
```

### Try Different Meter Numbers
```bash
for meter in "1234567890" "1111111111" "9999999999" "5555555555"; do
  echo "Testing with meter: $meter"
  
  curl -X POST "https://sandbox.payscribe.ng/api/v1/electricity/vend" \
    -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"meter_number\": \"${meter}\",
      \"meter_type\": \"postpaid\",
      \"amount\": 5000,
      \"service\": \"ikedc\",
      \"customer_name\": \"TEST\",
      \"phone\": \"08012345670\",
      \"ref\": \"bill-$(date +%s)\"
    }" \
    -s | jq '.'
done
```

### Try Different Services
```bash
services=("ikedc" "ekedc" "enugu" "ibadan")

for service in "${services[@]}"; do
  echo "Testing service: $service"
  
  curl -X POST "https://sandbox.payscribe.ng/api/v1/electricity/vend" \
    -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"service\": \"${service}\",
      \"meter_number\": \"1234567890\",
      \"meter_type\": \"postpaid\",
      \"amount\": 5000,
      \"customer_name\": \"TEST\",
      \"phone\": \"08012345670\",
      \"ref\": \"bill-${service}-$(date +%s)\"
    }" \
    -s | jq '.'
done
```

---

## 3. Troubleshooting with Verbose Output

### See Full Headers & Body
```bash
curl -X POST "https://sandbox.payscribe.ng/api/v1/data/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "network": "mtn",
    "recipient": "08012345670",
    "plan": "PSPLAN_531",
    "ref": "test-001"
  }' \
  -v  # Verbose: shows headers, request/response
```

### Check Response Headers Only
```bash
curl -I -X POST "https://sandbox.payscribe.ng/api/v1/data/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json"
```

### Pretty Print Response
```bash
curl -X POST "https://sandbox.payscribe.ng/api/v1/data/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "network": "mtn",
    "recipient": "08012345670",
    "plan": "PSPLAN_531",
    "ref": "test-001"
  }' \
  -s | jq '.'  # Pretty print JSON
```

---

## 4. PowerShell Equivalent Commands

### Data Vending Test (PowerShell)
```powershell
$apiKey = "your_api_key_here"
$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

$body = @{
    "network" = "mtn"
    "recipient" = "08012345670"
    "plan" = "PSPLAN_531"
    "ref" = "test-001"
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "https://sandbox.payscribe.ng/api/v1/data/vend" `
    -Method POST `
    -Headers $headers `
    -Body $body

$response.Content | ConvertFrom-Json | ConvertTo-Json
```

### Bill Payment Test (PowerShell)
```powershell
$apiKey = "your_api_key_here"
$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

$body = @{
    "service" = "ikedc"
    "meter_number" = "1234567890"
    "meter_type" = "postpaid"
    "amount" = 5000
    "customer_name" = "TEST"
    "phone" = "08012345670"
    "ref" = "bill-test-001"
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "https://sandbox.payscribe.ng/api/v1/electricity/vend" `
    -Method POST `
    -Headers $headers `
    -Body $body

$response.Content | ConvertFrom-Json | ConvertTo-Json
```

---

## 5. Expected Responses

### ✅ Successful Data Vending
```json
{
  "status": true,
  "description": "Data purchase successful",
  "message": {
    "details": {
      "trans_id": "20231214123456789",
      "transaction_status": "success",
      "amount": 500,
      "total_charge": 500
    }
  }
}
```

### ❌ Failed Data Vending (Current)
```json
{
  "status": false,
  "description": "No valid number to process. See errors",
  "errors": "08012345678"
}
```
**Solution:** Ask PayScribe for valid test numbers

### ❌ Failed Bill Payment (Current)
```json
{
  "status": false,
  "description": "User not authenticated. Please use your valid token",
  "status_code": 401
}
```
**Solution:** Verify API key has bill payment permissions

---

## 6. What to Record & Send to PayScribe

Run these and save output:

```bash
# 1. Show your data vending attempt
echo "=== DATA VENDING TEST ===" > payscribe_test_output.txt
curl -X POST "https://sandbox.payscribe.ng/api/v1/data/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"network":"mtn","recipient":"08012345670","plan":"PSPLAN_531","ref":"test-001"}' \
  -v >> payscribe_test_output.txt 2>&1

# 2. Show your bill payment attempt
echo -e "\n=== BILL PAYMENT TEST ===" >> payscribe_test_output.txt
curl -X POST "https://sandbox.payscribe.ng/api/v1/electricity/vend" \
  -H "Authorization: Bearer ${PAYSCRIBE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"service":"ikedc","meter_number":"1234567890","meter_type":"postpaid","amount":5000,"customer_name":"TEST","phone":"08012345670","ref":"bill-001"}' \
  -v >> payscribe_test_output.txt 2>&1

# Send this file to PayScribe support
cat payscribe_test_output.txt
```

This gives them:
- Exact request format
- Exact response with headers
- Status codes
- Error messages


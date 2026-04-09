#!/bin/bash
# Local testing script for Lambda function using Docker
# This allows you to test the function locally before deploying to AWS

set -e

echo "======================================"
echo "Local Lambda Function Testing"
echo "======================================"

# Check if test file is provided
if [ -z "$1" ]; then
    echo "Usage: ./test_local.sh <pdf_or_image_file>"
    echo "Example: ./test_local.sh sample.pdf"
    exit 1
fi

TEST_FILE="$1"

if [ ! -f "$TEST_FILE" ]; then
    echo "Error: File '$TEST_FILE' not found"
    exit 1
fi

echo "Test file: $TEST_FILE"

# Build the Docker image if needed
if ! docker images | grep -q "lambda-layer-builder"; then
    echo "Building Docker image..."
    docker build -t lambda-layer-builder .
fi

# Create test event
echo "Encoding test file..."
BASE64_CONTENT=$(base64 -i "$TEST_FILE" | tr -d '\n')

cat > test_event.json <<EOF
{
  "body": "$BASE64_CONTENT",
  "isBase64Encoded": true,
  "options": {
    "extract_barcodes": true
  }
}
EOF

echo "Test event created: test_event.json"

# Run function in Docker container
echo "Running Lambda function in Docker..."

docker run --rm \
    -v "$(pwd)/lambda_handler_no_textract.py:/var/task/lambda_function.py" \
    -v "$(pwd)/test_event.json:/tmp/test_event.json" \
    -e TESSDATA_PREFIX=/opt/share/tessdata \
    -e LD_LIBRARY_PATH=/opt/lib:/opt/lib64 \
    lambda-layer-builder \
    python3 -c "
import json
import sys
sys.path.insert(0, '/layer/python')
from lambda_function import lambda_handler

with open('/tmp/test_event.json') as f:
    event = json.load(f)

result = lambda_handler(event, None)
print(json.dumps(result, indent=2))
"

echo ""
echo "======================================"
echo "Test complete!"
echo "======================================"

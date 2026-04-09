#!/bin/bash
# Package the Lambda function code for deployment
# This creates a deployment package with just the function code

set -e  # Exit on error

echo "======================================"
echo "Packaging Lambda Function"
echo "======================================"

# Configuration
FUNCTION_NAME="pdf-ocr-function"
OUTPUT_DIR="./lambda_function_output"

# Clean up previous builds
echo "Cleaning up previous builds..."
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}

# Copy function code
echo "Copying function code..."
cp lambda_handler_no_textract.py ${OUTPUT_DIR}/lambda_function.py

# Create deployment package
echo "Creating function.zip..."
cd ${OUTPUT_DIR}
zip -r9 ../function.zip lambda_function.py
cd ..

# Get package size
FUNCTION_SIZE=$(du -h function.zip | cut -f1)
echo ""
echo "======================================"
echo "Function packaged successfully!"
echo "======================================"
echo "Location: ./function.zip"
echo "Size: ${FUNCTION_SIZE}"
echo ""
echo "The function code has been renamed to lambda_function.py"
echo "Handler: lambda_function.lambda_handler"
echo ""
echo "Next steps:"
echo "1. Ensure the layer is already created and published"
echo "2. Upload function.zip to AWS Lambda"
echo "3. Set handler to: lambda_function.lambda_handler"
echo "4. Set runtime to: Python 3.12"
echo "5. Attach the layer you created earlier"
echo "6. Configure environment variables (see DEPLOYMENT.md)"
echo "======================================"

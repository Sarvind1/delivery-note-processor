# AWS Lambda Deployment Guide
## PDF OCR Processing with Tesseract, zbar, and PyMuPDF

This guide explains how to deploy the `lambda_handler_no_textract.py` function to AWS Lambda with all necessary dependencies.

---

## Overview

The deployment consists of two components:
1. **Lambda Layer** - Contains native binaries (Tesseract, zbar, poppler) and Python packages
2. **Lambda Function** - Contains your application code

---

## Prerequisites

- Docker installed and running
- AWS CLI configured with appropriate credentials
- AWS account with Lambda permissions
- Bash shell (Linux/macOS or WSL on Windows)

---

## Step 1: Build the Lambda Layer

The layer contains all compiled native dependencies and Python packages.

### 1.1 Make build script executable

```bash
chmod +x build_layer.sh
```

### 1.2 Run the build script

```bash
./build_layer.sh
```

This will:
- Build a Docker image based on Amazon Linux 2023 (matching Lambda runtime)
- Compile Tesseract OCR from source
- Compile zbar barcode library from source
- Install poppler-utils for PDF processing
- Install Python packages (pytesseract, pyzbar, PyMuPDF, Pillow, PyPDF2)
- Merge contents from `spare_layer/` directory
- Create `lambda_layer_output/layer.zip` with proper AWS layer structure

### 1.3 Verify layer.zip

```bash
ls -lh lambda_layer_output/layer.zip
```

Expected size: ~100-200 MB (varies based on dependencies)

---

## Step 2: Upload Layer to AWS Lambda

### Option A: Using AWS CLI

```bash
aws lambda publish-layer-version \
    --layer-name pdf-ocr-processing-layer \
    --description "Tesseract OCR, zbar, PyMuPDF, and dependencies for PDF processing" \
    --zip-file fileb://lambda_layer_output/layer.zip \
    --compatible-runtimes python3.12 \
    --compatible-architectures x86_64
```

**Note the Layer ARN** from the output - you'll need it later.

### Option B: Using AWS Console

1. Go to AWS Lambda Console → Layers
2. Click "Create layer"
3. Name: `pdf-ocr-processing-layer`
4. Upload `lambda_layer_output/layer.zip`
5. Compatible runtimes: Python 3.12
6. Architecture: x86_64
7. Click "Create"

---

## Step 3: Package the Lambda Function

### 3.1 Make package script executable

```bash
chmod +x package_function.sh
```

### 3.2 Run the package script

```bash
./package_function.sh
```

This creates `function.zip` containing your Lambda handler code.

---

## Step 4: Create Lambda Function

### Option A: Using AWS CLI

```bash
# Create the function
aws lambda create-function \
    --function-name pdf-ocr-processor \
    --runtime python3.12 \
    --role arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_LAMBDA_ROLE \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --timeout 300 \
    --memory-size 2048 \
    --environment Variables="{
        TESSDATA_PREFIX=/opt/share/tessdata,
        LD_LIBRARY_PATH=/opt/lib:/opt/lib64,
        FONTCONFIG_PATH=/opt/fonts
    }"

# Attach the layer (use the Layer ARN from Step 2)
aws lambda update-function-configuration \
    --function-name pdf-ocr-processor \
    --layers arn:aws:lambda:REGION:ACCOUNT:layer:pdf-ocr-processing-layer:VERSION
```

### Option B: Using AWS Console

1. Go to AWS Lambda Console → Functions
2. Click "Create function"
3. Function name: `pdf-ocr-processor`
4. Runtime: Python 3.12
5. Architecture: x86_64
6. Click "Create function"

7. **Upload function code:**
   - Code source → Upload from → .zip file
   - Upload `function.zip`
   - Handler: `lambda_function.lambda_handler`

8. **Attach layer:**
   - Scroll to "Layers" section
   - Click "Add a layer"
   - Choose "Custom layers"
   - Select `pdf-ocr-processing-layer`
   - Click "Add"

9. **Configure environment variables:**
   - Configuration → Environment variables
   - Add the following:
     - `TESSDATA_PREFIX` = `/opt/share/tessdata`
     - `LD_LIBRARY_PATH` = `/opt/lib:/opt/lib64`
     - `FONTCONFIG_PATH` = `/opt/fonts`

10. **Adjust function settings:**
    - Configuration → General configuration
    - Timeout: 300 seconds (5 minutes)
    - Memory: 2048 MB (recommended for image processing)
    - Ephemeral storage: 512 MB (default is fine)

---

## Step 5: Test the Function

### 5.1 Create test event

Create a test event with the following JSON:

```json
{
  "body": "BASE64_ENCODED_PDF_OR_IMAGE",
  "isBase64Encoded": true,
  "options": {
    "extract_barcodes": true
  }
}
```

### 5.2 Test with sample file

```bash
# Encode a test PDF/image file
base64 -i your_test_file.pdf -o test_base64.txt

# Create test event JSON
cat > test_event.json <<EOF
{
  "body": "$(cat test_base64.txt | tr -d '\n')",
  "isBase64Encoded": true,
  "options": {
    "extract_barcodes": true
  }
}
EOF

# Invoke function via CLI
aws lambda invoke \
    --function-name pdf-ocr-processor \
    --payload file://test_event.json \
    response.json

# View response
cat response.json | jq
```

---

## Expected Response Format

```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*"
  },
  "body": {
    "success": true,
    "results": [
      {
        "page": 1,
        "method": "barcode",
        "field": "inbship",
        "data": "12345",
        "confidence": 100.0,
        "page_data_base64": "..."
      }
    ],
    "summary": {
      "total_results": 1,
      "by_method": {
        "barcode": 1,
        "text": 0,
        "none": 0
      },
      "by_field": {
        "inbship": 1,
        "batch": 0
      }
    }
  }
}
```

---

## Configuration Options

### Lambda Function Settings

| Setting | Recommended Value | Notes |
|---------|------------------|-------|
| Runtime | Python 3.12 | Latest supported version |
| Memory | 2048 MB | OCR and image processing require significant memory |
| Timeout | 300 seconds | Depends on document size and complexity |
| Ephemeral storage | 512 MB | Default is sufficient for most cases |

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `TESSDATA_PREFIX` | `/opt/share/tessdata` | Tesseract language data location |
| `LD_LIBRARY_PATH` | `/opt/lib:/opt/lib64` | Shared library search path |
| `FONTCONFIG_PATH` | `/opt/fonts` | Font configuration for rendering |

### Application Configuration

Edit in `lambda_handler_no_textract.py`:

```python
ENABLE_BARCODE_DETECTION = True   # Enable/disable barcode detection
TESTING_MODE = False               # Enable to see all detection methods
```

---

## Troubleshooting

### Layer too large

If the layer exceeds 250 MB (uncompressed limit):

1. Remove unnecessary Tesseract language files (keep only `eng.traineddata`)
2. Strip debug symbols: `strip /opt/bin/* /opt/lib/*.so`
3. Remove test/docs from Python packages

### Tesseract not found

Check environment variables:
```python
import os
print(os.environ.get('TESSDATA_PREFIX'))
print(os.environ.get('LD_LIBRARY_PATH'))
```

### Library loading errors

Check if libraries are present:
```python
import subprocess
result = subprocess.run(['ls', '/opt/lib'], capture_output=True)
print(result.stdout.decode())
```

### Memory errors

- Increase Lambda memory to 3008 MB
- Process PDFs page-by-page instead of all at once
- Reduce image DPI in `_pdf_page_to_image()` (currently 300 DPI)

### Timeout errors

- Increase timeout to 900 seconds (15 minutes max)
- Optimize image processing (reduce DPI, skip barcode detection if not needed)
- Consider splitting large documents into smaller chunks

---

## Layer Structure

```
layer.zip
├── opt/
│   ├── bin/
│   │   ├── tesseract          # Tesseract OCR binary
│   │   └── zbarcam            # zbar utilities
│   ├── lib/
│   │   ├── libtesseract.so.*  # Tesseract libraries
│   │   ├── libzbar.so.*       # zbar libraries
│   │   ├── libpoppler.so.*    # Poppler PDF libraries
│   │   └── ...                # Other shared libraries
│   ├── share/
│   │   └── tessdata/
│   │       ├── eng.traineddata # English language data
│   │       └── osd.traineddata # Orientation detection
│   └── fonts/                  # Font files from spare_layer
└── python/
    ├── PIL/                    # Pillow
    ├── pytesseract/           # Tesseract Python wrapper
    ├── pyzbar/                # zbar Python wrapper
    ├── PyPDF2/                # PDF manipulation
    ├── fitz/                  # PyMuPDF
    └── ...                    # Other Python packages
```

---

## Updating the Layer

To update dependencies:

1. Modify `requirements.txt` or `Dockerfile`
2. Run `./build_layer.sh` again
3. Publish new layer version:
   ```bash
   aws lambda publish-layer-version \
       --layer-name pdf-ocr-processing-layer \
       --zip-file fileb://lambda_layer_output/layer.zip \
       --compatible-runtimes python3.12
   ```
4. Update function to use new layer version:
   ```bash
   aws lambda update-function-configuration \
       --function-name pdf-ocr-processor \
       --layers arn:aws:lambda:REGION:ACCOUNT:layer:pdf-ocr-processing-layer:NEW_VERSION
   ```

---

## Cost Optimization

1. **Use appropriate memory**: Start with 2048 MB, adjust based on CloudWatch metrics
2. **Set timeout correctly**: Don't use max timeout if not needed
3. **Enable layer caching**: Layer contents are cached across invocations
4. **Consider Reserved Concurrency**: If you have predictable traffic

---

## Additional Resources

- [AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)
- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [zbar barcode reader](https://github.com/mchehab/zbar)
- [PyMuPDF Documentation](https://pymupdf.readthedocs.io/)

---

## Support

For issues or questions:
1. Check CloudWatch Logs for error messages
2. Verify layer structure and environment variables
3. Test locally using Docker before deploying
4. Review AWS Lambda limits and quotas

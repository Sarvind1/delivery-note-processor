# PDF Delivery Note Processor

A serverless AWS Lambda function that processes delivery note PDFs and images to extract structured data (order numbers, batch identifiers, barcodes) using OCR and barcode detection.

## Features

- **OCR Text Extraction**: Extract text from PDFs and images using Tesseract
- **Barcode Detection**: Detect and decode barcodes using zbar
- **Pattern Matching**: Extract specific identifiers (INBSHIP, BATCH numbers)
- **Multi-format Support**: Process PDFs, JPG, and PNG files
- **Error Normalization**: Handle common OCR errors (O→0, I→1, etc.)
- **Base64 API**: Accept and return base64-encoded documents
- **Testing Mode**: Compare multiple extraction methods for validation

## Tech Stack

- **OCR Engine**: Tesseract 5.3.4
- **Barcode Reader**: zbar 0.23.92
- **PDF Processing**: PyMuPDF (fitz), PyPDF2
- **Image Processing**: Pillow (PIL)
- **Runtime**: Python 3.12 on AWS Lambda
- **Deployment**: Docker containerization

## Setup

### Build the Lambda Layer

```bash
chmod +x build_layer.sh
./build_layer.sh
```

Creates `lambda_layer_output/layer.zip` (~150-200 MB) with all dependencies compiled for Lambda.

### Package the Function

```bash
chmod +x package_function.sh
./package_function.sh
```

Creates `function.zip` with the Lambda handler.

### Deploy to AWS

1. Upload `lambda_layer_output/layer.zip` as a new Lambda layer
2. Create Lambda function with Python 3.12 runtime
3. Attach the layer to the function
4. Upload `function.zip` as the function code
5. Set environment variables (see Configuration)
6. Increase memory to 2048 MB and timeout to 300 seconds

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

## Configuration

Edit `lambda_handler_no_textract.py`:

```python
ENABLE_BARCODE_DETECTION = True   # Enable/disable barcode detection
TESTING_MODE = False               # True: try all methods, False: stop at first match
```

### Required Environment Variables

```
TESSDATA_PREFIX=/opt/share/tessdata
LD_LIBRARY_PATH=/opt/lib:/opt/lib64
FONTCONFIG_PATH=/opt/fonts
```

## Usage

### Input

```json
{
  "body": "BASE64_ENCODED_PDF_OR_IMAGE",
  "isBase64Encoded": true,
  "options": {
    "extract_barcodes": true
  }
}
```

### Output

```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "results": [
      {
        "page": 1,
        "method": "barcode",
        "field": "inbship",
        "data": "12345",
        "confidence": 100.0
      }
    ],
    "summary": {
      "total_results": 1,
      "by_method": {"barcode": 1, "text": 0},
      "by_field": {"inbship": 1, "batch": 0}
    }
  }
}
```

## Files

- `lambda_handler_no_textract.py` - Main Lambda function with DocumentProcessor class
- `Dockerfile` - Build environment (Amazon Linux 2023)
- `build_layer.sh` - Lambda layer build script
- `DEPLOYMENT.md` - Deployment guide and troubleshooting

## Requirements

- Docker
- Bash shell
- AWS Lambda access (for deployment)

## Troubleshooting

- **No text extracted**: Verify `TESSDATA_PREFIX` environment variable is set
- **Barcode detection fails**: Check image quality and lighting
- **Lambda timeout**: Increase timeout to 300+ seconds for large PDFs
- **Out of memory**: Increase Lambda memory allocation

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed troubleshooting.

## License

Uses open-source components:
- Tesseract OCR (Apache 2.0)
- zbar (LGPL 2.1)
- PyMuPDF (AGPL 3.0 / commercial)
- Poppler (GPL)
# PDF Delivery Note Processor

AWS Lambda function for extracting identifiers (INBSHIP, BATCH) from delivery note documents using OCR and barcode detection.

## Features

- **OCR-based text extraction** using Tesseract for identifying INBSHIP and BATCH codes
- **Barcode detection** via pyzbar for fast identifier recognition
- **Multi-format support** for PDF, JPG, and PNG documents
- **Configurable detection strategy** with testing mode for validation
- **OCR error handling** with digit normalization (common OCR errors like O→0, I→1)
- **AWS Lambda optimized** with pre-built dependency layer

## Tech Stack

- **Python 3.12**
- **Tesseract OCR** for text extraction
- **PyMuPDF** (fitz) for PDF handling
- **PyPDF2** for PDF manipulation
- **Pillow (PIL)** for image processing
- **pyzbar** for barcode detection
- **AWS Lambda** runtime

## Setup

1. Extract the Lambda layer from `lambda_layer_output/layer.zip` to your AWS Lambda environment
2. Deploy the handler from `lambda_function_output/lambda_function.py` as your Lambda function
3. Ensure the Lambda execution role has permissions to invoke the function with base64-encoded document payloads

## Usage

The Lambda handler expects a JSON payload with base64-encoded document content:

```json
{
  "document": "<base64-encoded-file-content>",
  "filename": "delivery_note.pdf"
}
```

Returns identified codes:
```json
{
  "inbship": "12345",
  "batch": "1234567",
  "source": "barcode" | "ocr"
}
```

## Configuration

Edit `DocumentProcessor` in the handler:
- `ENABLE_BARCODE_DETECTION` - Enable/disable barcode scanning
- `TESTING_MODE` - Return all detection results vs. stop at first match

## Deployment

See `DEPLOYMENT.md` for detailed AWS Lambda layer and function deployment instructions.
#!/bin/bash
# Build script for creating AWS Lambda Layer with Tesseract, zbar, and dependencies
# This script uses Docker to compile everything in a Lambda-compatible environment

set -e  # Exit on error

echo "======================================"
echo "Building Lambda Layer with Docker"
echo "======================================"

# Configuration
IMAGE_NAME="lambda-layer-builder"
LAYER_NAME="pdf-ocr-layer"
OUTPUT_DIR="./lambda_layer_output"

# Clean up previous builds
echo "Cleaning up previous builds..."
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}

# Build Docker image
echo "Building Docker image..."
docker build -t ${IMAGE_NAME} .

# Create a container and copy the layer files
echo "Extracting layer files from Docker container..."
CONTAINER_ID=$(docker create ${IMAGE_NAME})

# Copy layer directory from container
docker cp ${CONTAINER_ID}:/layer ${OUTPUT_DIR}/layer_content

# Copy spare_layer contents if they exist (SELECTIVE - skip python directory)
if [ -d "./spare_layer" ]; then
    echo "Merging spare_layer contents (fonts and essential libs only)..."

    # Copy fonts
    if [ -d "./spare_layer/fonts" ]; then
        mkdir -p ${OUTPUT_DIR}/layer_content/opt/fonts
        cp -r ./spare_layer/fonts/* ${OUTPUT_DIR}/layer_content/opt/fonts/
    fi

    # Copy only essential shared libraries (skip python directory entirely)
    # Note: We're being selective here to avoid bloat from spare_layer
    echo "Skipping spare_layer/lib and spare_layer/python to reduce size..."
    # if [ -d "./spare_layer/lib" ]; then
    #     mkdir -p ${OUTPUT_DIR}/layer_content/opt/lib
    #     cp -r ./spare_layer/lib/* ${OUTPUT_DIR}/layer_content/opt/lib/
    # fi
fi

# Clean up container
docker rm ${CONTAINER_ID}

# Create proper layer structure
echo "Creating AWS Lambda layer structure..."
cd ${OUTPUT_DIR}

# Create final layer directory with proper structure
mkdir -p layer/opt
mkdir -p layer/python

# Move compiled binaries and libraries to /opt
if [ -d "layer_content/opt" ]; then
    cp -r layer_content/opt/* layer/opt/
fi

# Move Python packages to /python
if [ -d "layer_content/python" ]; then
    cp -r layer_content/python/* layer/python/
fi

# Final cleanup and size optimization
echo "Performing final cleanup..."
cd layer

# Remove any remaining .a files that slipped through
find . -name "*.a" -delete 2>/dev/null || true

# Remove .la files (libtool archives)
find . -name "*.la" -delete 2>/dev/null || true

# Check uncompressed size before zipping
UNCOMPRESSED_SIZE=$(du -sm . | cut -f1)
echo "Uncompressed layer size: ${UNCOMPRESSED_SIZE} MB"

if [ ${UNCOMPRESSED_SIZE} -gt 250 ]; then
    echo "WARNING: Uncompressed size (${UNCOMPRESSED_SIZE} MB) exceeds AWS Lambda limit (250 MB)!"
    echo "Consider removing fonts or other optional components."
fi

# Create layer.zip
echo "Creating layer.zip..."
zip -r9 ../layer.zip . -x "*.pyc" -x "*__pycache__*" -x "*.dist-info/*"
cd ..

# Get layer size
LAYER_SIZE=$(du -h layer.zip | cut -f1)
echo ""
echo "======================================"
echo "Layer built successfully!"
echo "======================================"
echo "Location: ${OUTPUT_DIR}/layer.zip"
echo "Size: ${LAYER_SIZE}"
echo ""
echo "Layer structure:"
echo "  /opt/bin/         - Tesseract and zbar binaries"
echo "  /opt/lib/         - Shared libraries"
echo "  /opt/share/       - Tesseract language data"
echo "  /python/          - Python packages"
echo ""
echo "Next steps:"
echo "1. Upload layer.zip to AWS Lambda"
echo "2. Create a Lambda function with Python 3.12 runtime"
echo "3. Attach this layer to your function"
echo "4. Set environment variables:"
echo "   - TESSDATA_PREFIX=/opt/share/tessdata"
echo "   - LD_LIBRARY_PATH=/opt/lib:/opt/lib64"
echo "======================================"

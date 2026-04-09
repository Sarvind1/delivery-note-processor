# Dockerfile for building AWS Lambda Layer with Tesseract, zbar, and PDF processing libraries
# Base: Amazon Linux 2023 (matches Lambda runtime)

FROM public.ecr.aws/lambda/python:3.12

# Install build dependencies and native libraries
RUN dnf install -y \
    # Build tools
    gcc \
    gcc-c++ \
    make \
    cmake \
    automake \
    autoconf \
    libtool \
    pkg-config \
    gettext \
    gettext-devel \
    # Image processing libraries
    libjpeg-devel \
    libpng-devel \
    libtiff-devel \
    giflib-devel \
    zlib-devel \
    # PDF processing
    poppler \
    poppler-utils \
    poppler-devel \
    # Font libraries (for rendering)
    fontconfig-devel \
    freetype-devel \
    # Additional utilities
    wget \
    tar \
    zip \
    unzip \
    git \
    ImageMagick-devel \
    && dnf clean all

# Install Leptonica from source (required for Tesseract)
WORKDIR /tmp
RUN wget https://github.com/DanBloomberg/leptonica/releases/download/1.84.1/leptonica-1.84.1.tar.gz && \
    tar -xzf leptonica-1.84.1.tar.gz && \
    cd leptonica-1.84.1 && \
    ./configure --prefix=/opt && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf leptonica-1.84.1 leptonica-1.84.1.tar.gz && \
    # Remove static library and development files
    rm -f /opt/lib/libleptonica.a && \
    strip --strip-all /opt/lib/libleptonica.so* 2>/dev/null || true

# Install Tesseract OCR from source (for latest version and full language support)
WORKDIR /tmp
ENV PKG_CONFIG_PATH=/opt/lib/pkgconfig:$PKG_CONFIG_PATH
ENV LD_LIBRARY_PATH=/opt/lib:$LD_LIBRARY_PATH
RUN wget https://github.com/tesseract-ocr/tesseract/archive/5.3.4.tar.gz && \
    tar -xzf 5.3.4.tar.gz && \
    cd tesseract-5.3.4 && \
    ./autogen.sh && \
    ./configure --prefix=/opt LEPTONICA_CFLAGS="-I/opt/include/leptonica" LEPTONICA_LIBS="-L/opt/lib -lleptonica" && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf tesseract-5.3.4 5.3.4.tar.gz && \
    # Remove static library and strip binaries
    rm -f /opt/lib/libtesseract.a && \
    strip --strip-all /opt/bin/tesseract 2>/dev/null || true && \
    strip --strip-all /opt/lib/libtesseract.so* 2>/dev/null || true

# Download Tesseract language data (English only, skip osd to save 10MB)
RUN mkdir -p /opt/share/tessdata && \
    cd /opt/share/tessdata && \
    wget https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata

# Install zbar from source (for better barcode detection)
WORKDIR /tmp
RUN wget https://github.com/mchehab/zbar/archive/refs/tags/0.23.92.tar.gz && \
    tar -xzf 0.23.92.tar.gz && \
    cd zbar-0.23.92 && \
    autoreconf -vfi && \
    ./configure --prefix=/opt --without-qt --without-gtk --without-x --without-python --disable-video && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf zbar-0.23.92 0.23.92.tar.gz && \
    # Remove static library and strip binaries
    rm -f /opt/lib/libzbar.a && \
    strip --strip-all /opt/bin/zbarimg 2>/dev/null || true && \
    strip --strip-all /opt/lib/libzbar.so* 2>/dev/null || true

# Set environment variables for library paths (extend existing)
ENV LD_LIBRARY_PATH=/opt/lib:/opt/lib64:$LD_LIBRARY_PATH
ENV TESSDATA_PREFIX=/opt/share/tessdata

# Comprehensive cleanup of development files before creating layer
RUN rm -rf /opt/include && \
    rm -rf /opt/lib/pkgconfig && \
    rm -rf /opt/lib/*.la && \
    rm -rf /opt/share/doc && \
    rm -rf /opt/share/man && \
    rm -rf /opt/share/locale && \
    find /opt/lib -name "*.a" -delete && \
    strip --strip-all /opt/lib/*.so* 2>/dev/null || true

# Create layer directory structure
RUN mkdir -p /layer/opt /layer/python

# Copy compiled binaries and libraries to layer
RUN cp -r /opt/* /layer/opt/

# Copy Python requirements
COPY requirements.txt /tmp/requirements.txt

# Install Python dependencies into layer
RUN pip install --no-cache-dir -r /tmp/requirements.txt -t /layer/python

# Aggressive cleanup of Python packages to reduce layer size
RUN find /layer/python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    find /layer/python -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true && \
    find /layer/python -type d -name "test" -exec rm -rf {} + 2>/dev/null || true && \
    find /layer/python -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true && \
    find /layer/python -type f -name "*.pyc" -delete && \
    find /layer/python -type f -name "*.pyo" -delete && \
    find /layer/python -type f -name "*.c" -delete && \
    find /layer/python -type f -name "*.h" -delete && \
    find /layer/python -name "*.so" -exec strip --strip-all {} + 2>/dev/null || true && \
    # Remove fitz_old if it exists (duplicate PyMuPDF)
    rm -rf /layer/python/fitz_old 2>/dev/null || true

# Set working directory
WORKDIR /layer

# Default command (for building)
CMD ["bash"]

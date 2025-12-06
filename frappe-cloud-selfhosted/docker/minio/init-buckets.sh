#!/bin/bash
# ============================================
# MinIO Buckets Initialization
# ============================================

set -e

echo "Waiting for MinIO to be ready..."
sleep 10

# Configure mc client
mc alias set local http://minio:9000 ${MINIO_ROOT_USER:-minioadmin} ${MINIO_ROOT_PASSWORD:-minioadmin}

# Create buckets
echo "Creating buckets..."
mc mb local/backups --ignore-existing
mc mb local/private --ignore-existing  
mc mb local/public --ignore-existing

# Set public bucket policy
echo "Setting bucket policies..."
mc anonymous set download local/public

echo "✅ MinIO buckets initialized successfully!"

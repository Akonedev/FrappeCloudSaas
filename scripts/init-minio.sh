#!/bin/bash
# =============================================================================
# Frappe Cloud - Initialize MinIO Buckets
# =============================================================================
set -e

MINIO_ALIAS="local"
BUCKETS=("backups" "assets" "private" "builds")

echo "⏳ Waiting for MinIO to be ready..."
until mc alias set "$MINIO_ALIAS" http://localhost:9000 "${MINIO_ROOT_USER:-minioadmin}" "${MINIO_ROOT_PASSWORD:-minioadmin123}" 2>/dev/null; do
    sleep 2
done
echo "✅ MinIO is ready!"

echo "📁 Creating buckets..."
for bucket in "${BUCKETS[@]}"; do
    mc mb "$MINIO_ALIAS/$bucket" 2>/dev/null || echo "  Bucket $bucket already exists"
done

echo "🔒 Setting bucket policies..."
mc anonymous set download "$MINIO_ALIAS/assets" 2>/dev/null || true

echo "✅ MinIO initialization complete!"

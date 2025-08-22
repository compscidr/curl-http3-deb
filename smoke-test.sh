#!/bin/bash

set -e

echo "🚀 Running smoke test for curl-http3-deb Docker image..."
echo

# Build the Docker image
echo "📦 Building Docker image (this may take several minutes)..."
docker build -f Dockerfile --target curl -t curl-http3-smoke-test .

echo
echo "✅ Docker image built successfully!"
echo

# Test the built image
echo "🧪 Testing the built Docker image..."

echo "  → Testing curl version..."
docker run --rm curl-http3-smoke-test --version

echo
echo "  → Testing curl help..."
docker run --rm curl-http3-smoke-test --help > /dev/null && echo "    ✓ curl help works"

echo
echo "  → Checking available features and protocols..."
docker run --rm curl-http3-smoke-test --version | grep -A5 -B1 "Features\|Protocols"

echo
echo "🎉 Smoke test completed successfully!"
echo "   The Docker image builds correctly and curl is functional."
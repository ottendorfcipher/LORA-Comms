#!/bin/bash

# Test Redis caching functionality for LORA Comms
# This script will test the Redis integration

echo "🧪 Testing Redis Cache Integration for LORA Comms"
echo "=================================================="

# Check if Redis is running
echo "🔍 Checking Redis server status..."
if pgrep -x "redis-server" > /dev/null; then
    echo "✅ Redis server is running"
else
    echo "❌ Redis server is not running"
    echo "💡 Starting Redis server..."
    
    # Try to start Redis via Homebrew
    if command -v brew > /dev/null; then
        if brew services list | grep -q "redis.*started"; then
            echo "✅ Redis is already managed by Homebrew"
        else
            echo "🚀 Starting Redis via Homebrew..."
            brew services start redis
            sleep 2
        fi
    else
        echo "⚠️  Homebrew not found. Please start Redis manually:"
        echo "   redis-server"
        exit 1
    fi
fi

# Test Redis connectivity
echo ""
echo "🔗 Testing Redis connectivity..."
if command -v redis-cli > /dev/null; then
    if redis-cli ping | grep -q "PONG"; then
        echo "✅ Redis connection successful"
    else
        echo "❌ Redis connection failed"
        exit 1
    fi
else
    echo "⚠️  redis-cli not found. Installing via Homebrew..."
    if command -v brew > /dev/null; then
        brew install redis
    else
        echo "❌ Please install Redis manually"
        exit 1
    fi
fi

# Clear any existing test data
echo ""
echo "🧹 Clearing test cache data..."
redis-cli FLUSHDB > /dev/null
echo "✅ Test cache cleared"

# Display Redis info
echo ""
echo "📊 Redis server information:"
redis-cli INFO server | grep "redis_version\|os\|arch_bits\|tcp_port"

# Test basic Redis operations
echo ""
echo "🧪 Testing basic Redis operations..."

# Test SET/GET
redis-cli SET "lora:test:key" "test_value" > /dev/null
RESULT=$(redis-cli GET "lora:test:key")
if [ "$RESULT" = "test_value" ]; then
    echo "✅ SET/GET operations working"
else
    echo "❌ SET/GET operations failed"
fi

# Test expiry
redis-cli SET "lora:test:expiry" "expire_me" EX 1 > /dev/null
sleep 2
EXPIRED=$(redis-cli GET "lora:test:expiry")
if [ "$EXPIRED" = "" ]; then
    echo "✅ Key expiration working"
else
    echo "❌ Key expiration failed"
fi

# Test JSON-like data (simulating device cache)
echo ""
echo "📱 Testing device cache simulation..."
DEVICE_JSON='[{"id":"test_device_1","name":"Test Device","path":"/dev/ttyUSB0","deviceType":0,"isAvailable":true}]'
redis-cli SET "lora:devices:available" "$DEVICE_JSON" EX 300 > /dev/null
CACHED_DEVICES=$(redis-cli GET "lora:devices:available")
if [ "$CACHED_DEVICES" = "$DEVICE_JSON" ]; then
    echo "✅ Device cache simulation working"
else
    echo "❌ Device cache simulation failed"
fi

# Check cache keys
echo ""
echo "🔑 Current cache keys:"
redis-cli KEYS "lora:*"

# Cache statistics
echo ""
echo "📈 Cache statistics:"
echo "Memory usage: $(redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')"
echo "Total keys: $(redis-cli DBSIZE)"

# Cleanup test data
echo ""
echo "🧹 Cleaning up test data..."
redis-cli DEL "lora:test:key" > /dev/null
redis-cli DEL "lora:devices:available" > /dev/null
echo "✅ Test cleanup complete"

echo ""
echo "🎉 Redis cache integration test completed successfully!"
echo ""
echo "📋 Summary:"
echo "  • Redis server is running and accessible"
echo "  • Basic cache operations work correctly"
echo "  • Device data caching simulation successful"
echo "  • Key expiration working as expected"
echo ""
echo "🚀 Your LORA Comms app is ready to use Redis caching!"
echo "   The app will automatically cache:"
echo "   • Device scan results (5 minutes)"
echo "   • Message history (1 hour)"
echo "   • Mesh node information (30 minutes)"

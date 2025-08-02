#!/bin/bash

# Dedicated Rust Mathematical Engine Deployment Script
# This script handles the deployment of the actual Rust contract using gblend

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
RPC_URL=${RPC_URL:-"http://localhost:8545"}
PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}
RUST_CONTRACT_DIR="rust-contracts"
OUTPUT_FILE="rust_engine_address.txt"

echo -e "${BLUE}🦀 Deploying Rust Mathematical Engine${NC}"
echo "=================================="

# Check if gblend is available
if ! command -v gblend &> /dev/null; then
    echo -e "${RED}✗${NC} gblend not found!"
    echo ""
    echo "To deploy the actual Rust mathematical engine, you need gblend installed."
    echo "Please install gblend from: https://docs.fluentlabs.xyz"
    echo ""
    echo -e "${YELLOW}For demo purposes, you can run the tests with a mock engine.${NC}"
    echo -e "${YELLOW}However, this won't show the true benefits of blended execution.${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} gblend found"

# Check if Rust contract directory exists
if [ ! -d "$RUST_CONTRACT_DIR" ]; then
    echo -e "${RED}✗${NC} Rust contract directory not found: $RUST_CONTRACT_DIR"
    exit 1
fi

echo -e "${GREEN}✓${NC} Rust contract directory found"

# Navigate to Rust contract directory
cd "$RUST_CONTRACT_DIR"

echo -e "\n${BLUE}📦 Building Rust contract...${NC}"

# Build the Rust contract
if ! gblend build; then
    echo -e "${RED}✗${NC} Failed to build Rust contract"
    exit 1
fi

echo -e "${GREEN}✓${NC} Rust contract built successfully"

echo -e "\n${BLUE}🚀 Deploying to network...${NC}"
echo "RPC URL: $RPC_URL"

# Deploy the contract
DEPLOY_OUTPUT=$(gblend deploy MathematicalEngine --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" 2>&1)
DEPLOY_STATUS=$?

if [ $DEPLOY_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Rust contract deployed successfully"
    
    # Extract the contract address from the output
    # This assumes gblend outputs the address in a predictable format
    # Adjust the regex based on actual gblend output format
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
    
    if [ -n "$CONTRACT_ADDRESS" ]; then
        echo "Contract Address: $CONTRACT_ADDRESS"
        
        # Save the address to file
        cd ..
        echo "$CONTRACT_ADDRESS" > "$OUTPUT_FILE"
        echo -e "${GREEN}✓${NC} Contract address saved to $OUTPUT_FILE"
        
        # Update deployment.json if it exists
        if [ -f "deployment.json" ]; then
            # Use jq to update the JSON if available, otherwise append
            if command -v jq &> /dev/null; then
                jq ". + {\"mathEngine\": \"$CONTRACT_ADDRESS\"}" deployment.json > deployment_temp.json
                mv deployment_temp.json deployment.json
                echo -e "${GREEN}✓${NC} Updated deployment.json with Rust engine address"
            else
                echo -e "${YELLOW}⚠${NC} jq not found, manually update deployment.json with address: $CONTRACT_ADDRESS"
            fi
        fi
        
        echo ""
        echo -e "${GREEN}🎉 Rust Mathematical Engine deployed successfully!${NC}"
        echo "Address: $CONTRACT_ADDRESS"
        echo "Network: $RPC_URL"
        echo ""
        echo "You can now run the Solidity deployment script to complete the setup."
        
    else
        echo -e "${RED}✗${NC} Could not extract contract address from gblend output"
        echo "Deploy output:"
        echo "$DEPLOY_OUTPUT"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Failed to deploy Rust contract"
    echo "Error output:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi
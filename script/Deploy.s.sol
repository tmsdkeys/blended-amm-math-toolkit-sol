// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/BasicAMM.sol";
import "../src/EnhancedAMM.sol";
import "../src/IMathematicalEngine.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Simple ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Deploy
 * @dev Deployment script for both Basic and Enhanced AMM systems
 */
contract Deploy is Script {
    
    // Deployment addresses will be saved here
    address public tokenA;
    address public tokenB;
    address public basicAMM;
    address public enhancedAMM;
    address public mathEngine;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy test tokens
        console.log("\n=== Deploying Test Tokens ===");
        tokenA = address(new MockERC20("Token A", "TKNA"));
        tokenB = address(new MockERC20("Token B", "TKNB"));
        
        console.log("Token A deployed at:", tokenA);
        console.log("Token B deployed at:", tokenB);
        
        // Step 2: Deploy Rust Mathematical Engine
        console.log("\n=== Deploying Rust Mathematical Engine ===");
        // Note: In real deployment, this would be done with gblend
        // For now, we'll use a placeholder address or deploy a mock
        mathEngine = _deployMathEngine();
        console.log("Math Engine deployed at:", mathEngine);
        
        // Step 3: Deploy Basic AMM (pure Solidity)
        console.log("\n=== Deploying Basic AMM ===");
        basicAMM = address(new BasicAMM(
            tokenA,
            tokenB,
            "Basic AMM LP Token",
            "BASIC-LP"
        ));
        console.log("Basic AMM deployed at:", basicAMM);
        
        // Step 4: Deploy Enhanced AMM (with Rust engine)
        console.log("\n=== Deploying Enhanced AMM ===");
        enhancedAMM = address(new EnhancedAMM(
            tokenA,
            tokenB,
            mathEngine,
            "Enhanced AMM LP Token",
            "ENHANCED-LP"
        ));
        console.log("Enhanced AMM deployed at:", enhancedAMM);
        
        // Step 5: Initial setup and funding
        console.log("\n=== Initial Setup ===");
        _setupInitialLiquidity();
        
        vm.stopBroadcast();
        
        // Step 6: Save deployment info
        _saveDeploymentInfo();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Basic AMM:", basicAMM);
        console.log("Enhanced AMM:", enhancedAMM);
        console.log("Math Engine:", mathEngine);
    }
    
    function _deployMathEngine() internal returns (address) {
        // In a real blended deployment, this would be:
        // gblend deploy MathematicalEngine
        
        // For Phase 1 demo, we'll deploy a mock that simulates Rust behavior
        bytes memory bytecode = abi.encodePacked(
            type(MockMathEngine).creationCode
        );
        
        address engine;
        assembly {
            engine := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(engine != address(0), "Math engine deployment failed");
        return engine;
    }
    
    function _setupInitialLiquidity() internal {
        MockERC20 tokenAContract = MockERC20(tokenA);
        MockERC20 tokenBContract = MockERC20(tokenB);
        
        // Mint additional tokens for testing
        tokenAContract.mint(msg.sender, 100000 * 10**18);
        tokenBContract.mint(msg.sender, 100000 * 10**18);
        
        // Approve both AMMs for testing
        tokenAContract.approve(basicAMM, type(uint256).max);
        tokenBContract.approve(basicAMM, type(uint256).max);
        tokenAContract.approve(enhancedAMM, type(uint256).max);
        tokenBContract.approve(enhancedAMM, type(uint256).max);
        
        console.log("Tokens minted and approved for both AMMs");
    }
    
    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "tokenA": "', vm.toString(tokenA), '",\n',
            '  "tokenB": "', vm.toString(tokenB), '",\n',
            '  "basicAMM": "', vm.toString(basicAMM), '",\n',
            '  "enhancedAMM": "', vm.toString(enhancedAMM), '",\n',
            '  "mathEngine": "', vm.toString(mathEngine), '",\n',
            '  "deployer": "', vm.toString(msg.sender), '"\n',
            "}"
        ));
        
        vm.writeFile("deployment.json", deploymentInfo);
        console.log("Deployment info saved to deployment.json");
    }
    
    uint256 constant salt = 12345;
}

/**
 * @title MockMathEngine
 * @dev Mock implementation of the Rust math engine for testing
 * In production, this would be the actual Rust contract
 */
contract MockMathEngine is IMathematicalEngine {
    
    function _calculatePreciseSquareRoot(uint256 value) internal pure returns (uint256) {
        // Simulate improved precision (this is still Solidity, but represents Rust behavior)
        if (value == 0) return 0;
        
        // Use a more precise approximation than basic Babylonian method
        uint256 z = (value + 1) / 2;
        uint256 y = value;
        
        // More iterations for better precision (Rust would be even better)
        for (uint256 i = 0; i < 10; i++) {
            if (z >= y) break;
            y = z;
            z = (value / z + z) / 2;
        }
        
        return y;
    }
    
    function calculatePreciseSquareRoot(uint256 value) external pure override returns (uint256) {
        return _calculatePreciseSquareRoot(value);
    }
    
    function calculatePreciseSlippage(SlippageParams calldata params) 
        external pure override returns (uint256) {
        // Simulate high-precision slippage calculation
        if (params.expectedOut == 0) return 0;
        
        uint256 actualOut = (params.amountIn * params.reserveOut) / (params.reserveIn + params.amountIn);
        
        if (params.expectedOut > actualOut) {
            // Return slippage in basis points (10000 = 100%)
            return ((params.expectedOut - actualOut) * 10000) / params.expectedOut;
        }
        
        return 0;
    }
    
    function calculateDynamicFee(VolatilityParams calldata params) 
        external pure override returns (uint256) {
        // Base fee: 30 basis points (0.3%)
        uint256 baseFee = 30;
        
        // Simple volatility adjustment (Rust would use exponential functions)
        uint256 volatilityAdjustment = params.priceVolatility / 100000; // Scale down
        
        // Volume adjustment
        uint256 volumeAdjustment = 0;
        if (params.liquidityDepth > 0) {
            volumeAdjustment = (params.volume24h * 10) / params.liquidityDepth; // Simplified ratio
        }
        
        uint256 dynamicFee = baseFee + volatilityAdjustment + volumeAdjustment;
        
        // Cap at 100 basis points (1%)
        return dynamicFee > 100 ? 100 : dynamicFee;
    }
    
    function optimizeSwapAmount(SwapParams calldata params) 
        external pure override returns (uint256) {
        // Simulate swap optimization (simplified)
        // In reality, Rust would use calculus-based optimization
        
        // For demo: return slightly optimized amount (95% of input for better slippage)
        return (params.amountIn * 95) / 100;
    }
    
    function findOptimalRoute(RouteHop[] calldata hops, uint256 amountIn) 
        external pure override returns (uint32[] memory route, uint256 amountOut) {
        // Simplified routing for demo
        if (hops.length == 0) {
            return (new uint32[](0), 0);
        }
        
        // For demo: always use direct route (first hop)
        route = new uint32[](1);
        route[0] = 0;
        
        // Calculate output through first hop
        RouteHop memory hop = hops[0];
        amountOut = (amountIn * 997 * hop.reserveOut) / (hop.reserveIn * 1000 + amountIn * 997);
        
        return (route, amountOut);
    }
    
    function calculateLPTokens(LiquidityParams calldata params) 
        external pure override returns (uint256) {
        if (params.totalSupply == 0) {
            // First liquidity: use more precise square root
            return _calculatePreciseSquareRoot(params.amount0 * params.amount1);
        } else {
            // Subsequent liquidity: use minimum ratio for precision
            uint256 liquidity0 = (params.amount0 * params.totalSupply) / params.amount0; // Would use actual reserves
            uint256 liquidity1 = (params.amount1 * params.totalSupply) / params.amount1; // Would use actual reserves
            
            return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
    }
}
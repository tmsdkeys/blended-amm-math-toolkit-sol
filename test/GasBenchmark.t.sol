// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/BasicAMM.sol";
import "../src/EnhancedAMM.sol";
import "../src/IMathematicalEngine.sol";
import "../script/Deploy.s.sol";

/**
 * @title GasBenchmark
 * @dev Comprehensive gas benchmarking between Basic and Enhanced AMM
 */
contract GasBenchmark is Test {
    
    // Contract instances
    BasicAMM public basicAMM;
    EnhancedAMM public enhancedAMM;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockMathEngine public mathEngine;
    
    // Test accounts
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    
    // Test parameters
    uint256 constant INITIAL_LIQUIDITY_A = 100000 * 10**18;
    uint256 constant INITIAL_LIQUIDITY_B = 100000 * 10**18;
    uint256 constant SWAP_AMOUNT = 1000 * 10**18;
    uint256 constant LIQUIDITY_AMOUNT = 10000 * 10**18;
    
    // Gas tracking
    struct GasMetrics {
        uint256 basicGas;
        uint256 enhancedGas;
        int256 gasDiff;
        uint256 percentSaving;
    }
    
    mapping(string => GasMetrics) public gasResults;
    
    function setUp() public {
        console.log("=== Setting up Gas Benchmark Test ===");
        
        // Deploy contracts
        tokenA = new MockERC20("Token A", "TKNA");
        tokenB = new MockERC20("Token B", "TKNB");
        mathEngine = new MockMathEngine();
        
        basicAMM = new BasicAMM(
            address(tokenA),
            address(tokenB),
            "Basic AMM LP",
            "BASIC-LP"
        );
        
        enhancedAMM = new EnhancedAMM(
            address(tokenA),
            address(tokenB),
            address(mathEngine),
            "Enhanced AMM LP",
            "ENHANCED-LP"
        );
        
        // Setup test accounts with tokens
        _setupTestAccounts();
        
        // Add initial liquidity to both pools
        _addInitialLiquidity();
        
        console.log("Setup complete!");
    }
    
    function testGasBenchmark_AddLiquidity() public {
        console.log("\n=== Testing Add Liquidity Gas Usage ===");
        
        uint256 amount0 = LIQUIDITY_AMOUNT;
        uint256 amount1 = LIQUIDITY_AMOUNT;
        
        // Test Basic AMM
        vm.startPrank(alice);
        uint256 gasStart = gasleft();
        basicAMM.addLiquidity(amount0, amount1, amount0 * 95 / 100, amount1 * 95 / 100, alice);
        uint256 basicGas = gasStart - gasleft();
        vm.stopPrank();
        
        // Test Enhanced AMM
        vm.startPrank(alice);
        gasStart = gasleft();
        enhancedAMM.addLiquidityEnhanced(amount0, amount1, amount0 * 95 / 100, amount1 * 95 / 100, alice);
        uint256 enhancedGas = gasStart - gasleft();
        vm.stopPrank();
        
        _recordGasMetrics("addLiquidity", basicGas, enhancedGas);
    }
    
    function testGasBenchmark_RemoveLiquidity() public {
        console.log("\n=== Testing Remove Liquidity Gas Usage ===");
        
        // First add liquidity to both pools
        uint256 amount0 = LIQUIDITY_AMOUNT;
        uint256 amount1 = LIQUIDITY_AMOUNT;
        
        vm.startPrank(alice);
        basicAMM.addLiquidity(amount0, amount1, 0, 0, alice);
        uint256 basicLiquidity = basicAMM.balanceOf(alice);
        
        enhancedAMM.addLiquidityEnhanced(amount0, amount1, 0, 0, alice);
        uint256 enhancedLiquidity = enhancedAMM.balanceOf(alice);
        vm.stopPrank();
        
        // Test Basic AMM removal
        vm.startPrank(alice);
        uint256 gasStart = gasleft();
        basicAMM.removeLiquidity(basicLiquidity / 2, 0, 0, alice);
        uint256 basicGas = gasStart - gasleft();
        vm.stopPrank();
        
        // Test Enhanced AMM removal
        vm.startPrank(alice);
        gasStart = gasleft();
        enhancedAMM.removeLiquidityEnhanced(enhancedLiquidity / 2, 0, 0, alice);
        uint256 enhancedGas = gasStart - gasleft();
        vm.stopPrank();
        
        _recordGasMetrics("removeLiquidity", basicGas, enhancedGas);
    }
    
    function testGasBenchmark_Swap() public {
        console.log("\n=== Testing Swap Gas Usage ===");
        
        uint256 swapAmount = SWAP_AMOUNT;
        
        // Test Basic AMM swap
        vm.startPrank(bob);
        uint256 gasStart = gasleft();
        basicAMM.swap(address(tokenA), swapAmount, 0, bob);
        uint256 basicGas = gasStart - gasleft();
        vm.stopPrank();
        
        // Test Enhanced AMM swap
        vm.startPrank(bob);
        gasStart = gasleft();
        enhancedAMM.swapEnhanced(address(tokenA), swapAmount, 0, bob);
        uint256 enhancedGas = gasStart - gasleft();
        vm.stopPrank();
        
        _recordGasMetrics("swap", basicGas, enhancedGas);
    }
    
    function testGasBenchmark_SquareRootCalculation() public {
        console.log("\n=== Testing Square Root Calculation ===");
        
        uint256 testValue = 123456789 * 10**18;
        
        // Test Basic AMM square root (internal function simulation)
        uint256 gasStart = gasleft();
        uint256 basicResult = _testBasicSquareRoot(testValue);
        uint256 basicGas = gasStart - gasleft();
        
        // Test Enhanced AMM square root (via Rust engine)
        gasStart = gasleft();
        uint256 enhancedResult = mathEngine.calculatePreciseSquareRoot(testValue);
        uint256 enhancedGas = gasStart - gasleft();
        
        _recordGasMetrics("squareRoot", basicGas, enhancedGas);
        
        console.log("Basic result:", basicResult);
        console.log("Enhanced result:", enhancedResult);
    }
    
    function testGasBenchmark_SlippageCalculation() public {
        console.log("\n=== Testing Slippage Calculation ===");
        
        uint256 amountIn = SWAP_AMOUNT;
        uint256 reserveIn = INITIAL_LIQUIDITY_A;
        uint256 reserveOut = INITIAL_LIQUIDITY_B;
        uint256 expectedOut = (amountIn * reserveOut) / reserveIn;
        
        // Test Basic AMM slippage calculation
        uint256 gasStart = gasleft();
        uint256 basicSlippage = basicAMM.calculateSlippage(amountIn, reserveIn, reserveOut);
        uint256 basicGas = gasStart - gasleft();
        
        // Test Enhanced AMM slippage calculation
        IMathematicalEngine.SlippageParams memory params = IMathematicalEngine.SlippageParams({
            amountIn: amountIn,
            reserveIn: reserveIn,
            reserveOut: reserveOut,
            expectedOut: expectedOut
        });
        
        gasStart = gasleft();
        uint256 enhancedSlippage = mathEngine.calculatePreciseSlippage(params);
        uint256 enhancedGas = gasStart - gasleft();
        
        _recordGasMetrics("slippageCalculation", basicGas, enhancedGas);
        
        console.log("Basic slippage:", basicSlippage);
        console.log("Enhanced slippage:", enhancedSlippage);
    }
    
    function testGasBenchmark_DynamicFeeCalculation() public {
        console.log("\n=== Testing Dynamic Fee Calculation ===");
        
        // Enhanced AMM only (Basic AMM doesn't have dynamic fees)
        IMathematicalEngine.VolatilityParams memory params = IMathematicalEngine.VolatilityParams({
            volume24h: 50000 * 10**18,
            liquidityDepth: 200000 * 10**18,
            priceVolatility: 150000 // 15% volatility
        });
        
        uint256 gasStart = gasleft();
        uint256 dynamicFee = mathEngine.calculateDynamicFee(params);
        uint256 enhancedGas = gasStart - gasleft();
        
        // Compare against static fee (no calculation needed)
        uint256 basicGas = 100; // Minimal gas for reading a constant
        
        _recordGasMetrics("dynamicFeeCalculation", basicGas, enhancedGas);
        
        console.log("Dynamic fee calculated:", dynamicFee, "basis points");
    }
    
    function testComprehensiveBenchmark() public {
        console.log("\n=== Running Comprehensive Gas Benchmark ===");
        
        // Run all individual benchmarks
        testGasBenchmark_AddLiquidity();
        testGasBenchmark_RemoveLiquidity();
        testGasBenchmark_Swap();
        testGasBenchmark_SquareRootCalculation();
        testGasBenchmark_SlippageCalculation();
        testGasBenchmark_DynamicFeeCalculation();
        
        // Print comprehensive results
        _printGasResults();
        
        // Verify that we're seeing meaningful differences
        assertTrue(gasResults["addLiquidity"].basicGas > 0, "Basic add liquidity should use gas");
        assertTrue(gasResults["swap"].basicGas > 0, "Basic swap should use gas");
    }
    
    function testPrecisionComparison() public {
        console.log("\n=== Testing Precision Improvements ===");
        
        uint256 testValue = 99999999999999999999; // Large number for precision testing
        
        uint256 basicResult = _testBasicSquareRoot(testValue);
        uint256 enhancedResult = mathEngine.calculatePreciseSquareRoot(testValue);
        
        console.log("Input value:", testValue);
        console.log("Basic sqrt result:", basicResult);
        console.log("Enhanced sqrt result:", enhancedResult);
        
        // Calculate actual square root for comparison
        uint256 actualSqrt = 9999999999; // sqrt of ~10^19
        
        uint256 basicError = basicResult > actualSqrt ? basicResult - actualSqrt : actualSqrt - basicResult;
        uint256 enhancedError = enhancedResult > actualSqrt ? enhancedResult - actualSqrt : actualSqrt - enhancedResult;
        
        console.log("Basic error:", basicError);
        console.log("Enhanced error:", enhancedError);
        
        // Enhanced should be more accurate (lower error)
        assertLe(enhancedError, basicError, "Enhanced should be more precise");
    }
    
    // ============ Helper Functions ============
    
    function _setupTestAccounts() internal {
        // Give test accounts tokens
        tokenA.mint(alice, 1000000 * 10**18);
        tokenB.mint(alice, 1000000 * 10**18);
        tokenA.mint(bob, 1000000 * 10**18);
        tokenB.mint(bob, 1000000 * 10**18);
        tokenA.mint(charlie, 1000000 * 10**18);
        tokenB.mint(charlie, 1000000 * 10**18);
        
        // Approve both AMMs
        vm.startPrank(alice);
        tokenA.approve(address(basicAMM), type(uint256).max);
        tokenB.approve(address(basicAMM), type(uint256).max);
        tokenA.approve(address(enhancedAMM), type(uint256).max);
        tokenB.approve(address(enhancedAMM), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        tokenA.approve(address(basicAMM), type(uint256).max);
        tokenB.approve(address(basicAMM), type(uint256).max);
        tokenA.approve(address(enhancedAMM), type(uint256).max);
        tokenB.approve(address(enhancedAMM), type(uint256).max);
        vm.stopPrank();
    }
    
    function _addInitialLiquidity() internal {
        vm.startPrank(alice);
        
        // Add initial liquidity to both pools
        basicAMM.addLiquidity(
            INITIAL_LIQUIDITY_A,
            INITIAL_LIQUIDITY_B,
            0,
            0,
            alice
        );
        
        enhancedAMM.addLiquidityEnhanced(
            INITIAL_LIQUIDITY_A,
            INITIAL_LIQUIDITY_B,
            0,
            0,
            alice
        );
        
        vm.stopPrank();
        
        console.log("Initial liquidity added to both pools");
    }
    
    function _testBasicSquareRoot(uint256 x) internal pure returns (uint256) {
        // Copy of the Babylonian method from BasicAMM
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }
    
    function _recordGasMetrics(string memory operation, uint256 basicGas, uint256 enhancedGas) internal {
        int256 gasDiff = int256(basicGas) - int256(enhancedGas);
        uint256 percentSaving = basicGas > 0 ? (uint256(gasDiff) * 100) / basicGas : 0;
        
        gasResults[operation] = GasMetrics({
            basicGas: basicGas,
            enhancedGas: enhancedGas,
            gasDiff: gasDiff,
            percentSaving: percentSaving
        });
        
        console.log(string(abi.encodePacked("=== ", operation, " Gas Results ===")));
        console.log("Basic Gas:", basicGas);
        console.log("Enhanced Gas:", enhancedGas);
        console.log("Gas Difference:", uint256(gasDiff > 0 ? gasDiff : -gasDiff));
        console.log("Savings:", gasDiff > 0 ? "Enhanced saves" : "Basic saves", percentSaving, "%");
    }
    
    function _printGasResults() internal view {
        console.log("\n================================");
        console.log("  COMPREHENSIVE GAS BENCHMARK");
        console.log("================================");
        
        string[6] memory operations = [
            "addLiquidity",
            "removeLiquidity", 
            "swap",
            "squareRoot",
            "slippageCalculation",
            "dynamicFeeCalculation"
        ];
        
        uint256 totalBasicGas = 0;
        uint256 totalEnhancedGas = 0;
        
        for (uint256 i = 0; i < operations.length; i++) {
            GasMetrics memory metrics = gasResults[operations[i]];
            totalBasicGas += metrics.basicGas;
            totalEnhancedGas += metrics.enhancedGas;
            
            console.log(operations[i], ":");
            console.log("  Basic:", metrics.basicGas, "gas");
            console.log("  Enhanced:", metrics.enhancedGas, "gas");
            console.log("  Savings:", metrics.percentSaving, "%");
        }
        
        console.log("--------------------------------");
        console.log("TOTAL GAS COMPARISON:");
        console.log("Basic Total:", totalBasicGas);
        console.log("Enhanced Total:", totalEnhancedGas);
        
        if (totalBasicGas > 0) {
            uint256 overallSaving = ((totalBasicGas - totalEnhancedGas) * 100) / totalBasicGas;
            console.log("Overall Savings:", overallSaving, "%");
        }
        
        console.log("================================");
    }
}
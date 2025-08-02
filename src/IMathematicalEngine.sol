// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMathematicalEngine
 * @dev Interface for the Rust-powered mathematical engine
 * Maps directly to the trait functions defined in the Rust contract
 */
interface IMathematicalEngine {
    
    // ============ Struct Definitions ============
    // These must match the Rust sol! macro definitions
    
    struct SwapParams {
        uint256 amountIn;
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 feeRate;
    }
    
    struct SlippageParams {
        uint256 amountIn;
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 expectedOut;
    }
    
    struct LiquidityParams {
        uint256 amount0;
        uint256 amount1;
        uint256 totalSupply;
    }
    
    struct RouteHop {
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;
    }
    
    struct VolatilityParams {
        uint256 volume24h;
        uint256 liquidityDepth;
        uint256 priceVolatility; // Scaled by 1e6
    }
    
    // ============ Core Mathematical Functions ============
    
    /**
     * @dev High-precision square root calculation
     * Replaces expensive Babylonian method in Solidity
     */
    function calculatePreciseSquareRoot(uint256 value) external returns (uint256);
    
    /**
     * @dev Calculate precise slippage using floating-point arithmetic
     * Provides much higher accuracy than Solidity integer division
     */
    function calculatePreciseSlippage(SlippageParams calldata params) external returns (uint256);
    
    /**
     * @dev Calculate dynamic fees based on market conditions
     * Uses exponential functions impossible in pure Solidity
     */
    function calculateDynamicFee(VolatilityParams calldata params) external returns (uint256);
    
    /**
     * @dev Optimize swap amount to minimize price impact
     * Uses calculus-based optimization impossible in Solidity
     */
    function optimizeSwapAmount(SwapParams calldata params) external returns (uint256);
    
    /**
     * @dev Find optimal multi-hop routing
     * Complex optimization impossible due to gas limits in Solidity
     */
    function findOptimalRoute(RouteHop[] calldata hops, uint256 amountIn) 
        external returns (uint32[] memory route, uint256 amountOut);
    
    /**
     * @dev Calculate LP tokens with high precision
     * Eliminates precision loss from Solidity integer arithmetic
     */
    function calculateLPTokens(LiquidityParams calldata params) external returns (uint256);
}
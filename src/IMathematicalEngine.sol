// SPDX-License-Identifier: MIT
// Auto-generated from Rust source
pragma solidity ^0.8.0;

interface IMathematicalEngine {
    struct SlippageParams {
        uint256 amount_in;
        uint256 reserve_in;
        uint256 reserve_out;
        uint256 fee_rate;
    }

    struct DynamicFeeParams {
        uint256 volatility;
        uint256 volume_24h;
        uint256 liquidity_depth;
    }

    struct OptimizationResult {
        uint256 optimal_amount;
        uint256 expected_output;
        uint256 price_impact;
    }

    struct Pool {
        uint256 reserve_in;
        uint256 reserve_out;
    }

    function calculatePreciseSquareRoot(uint256 value) external returns (uint256 _0);
    function calculatePreciseSlippage(SlippageParams memory params) external returns (uint256 _0);
    function calculateDynamicFee(DynamicFeeParams memory params) external returns (uint256 _0);
    function optimizeSwapAmount(uint256 total_amount, uint256 reserve_in, uint256 reserve_out, uint256 fee_rate) external returns (OptimizationResult memory _0);
    function calculateLpTokens(uint256 amount0, uint256 amount1) external returns (uint256 _0);
    function calculateImpermanentLoss(uint256 initial_price, uint256 current_price) external returns (uint256 _0);
    function findOptimalRoute(uint256 amount_in, Pool[] memory pools, uint256[] memory fee_rates) external returns (uint256 _0);
}

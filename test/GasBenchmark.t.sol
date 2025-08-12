// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BasicAMM.sol";
import "../src/EnhancedAMM.sol";
// Import the auto-generated interface
import "../out/MathematicalEngine.wasm/interface.sol";

contract GasBenchmarkTest is Test {
    BasicAMM public basicAMM;
    EnhancedAMM public enhancedAMM;
    IMathematicalEngine public mathEngine;
    
    address public tokenA;
    address public tokenB;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    uint256 constant INITIAL_LIQUIDITY = 100000 * 1e18;
    uint256 constant SWAP_AMOUNT = 1000 * 1e18;
    
    function setUp() public {
        // Deploy tokens
        MockERC20 _tokenA = new MockERC20("Token A", "TKNA");
        MockERC20 _tokenB = new MockERC20("Token B", "TKNB");
        tokenA = address(_tokenA);
        tokenB = address(_tokenB);
        
        // Deploy the Rust Mathematical Engine from WASM bytecode
        mathEngine = IMathematicalEngine(deployMathEngine());
        
        // Deploy AMMs
        basicAMM = new BasicAMM(tokenA, tokenB, "Basic LP", "BLP");
        enhancedAMM = new EnhancedAMM(
            tokenA,
            tokenB,
            address(mathEngine),
            "Enhanced LP",
            "ELP"
        );
        
        // Setup test accounts
        setupTestAccounts();
    }
    
    function deployMathEngine() internal returns (address) {
        // Read the WASM bytecode from the build artifact
        bytes memory wasmBytecode = vm.readFileBinary("out/MathematicalEngine/MathematicalEngine.json");
        
        // Deploy the WASM contract
        address deployed;
        assembly {
            deployed := create2(0, add(wasmBytecode, 0x20), mload(wasmBytecode), salt())
        }
        
        require(deployed != address(0), "Failed to deploy Math Engine");
        console.log("Math Engine deployed at:", deployed);
        
        return deployed;
    }
    
    function salt() internal view returns (bytes32) {
        return keccak256(abi.encode(address(this), block.timestamp));
    }
    
    function setupTestAccounts() internal {
        MockERC20(tokenA).mint(alice, INITIAL_LIQUIDITY * 10);
        MockERC20(tokenB).mint(alice, INITIAL_LIQUIDITY * 10);
        MockERC20(tokenA).mint(bob, SWAP_AMOUNT * 10);
        MockERC20(tokenB).mint(bob, SWAP_AMOUNT * 10);
        
        // Approve AMMs
        vm.startPrank(alice);
        MockERC20(tokenA).approve(address(basicAMM), type(uint256).max);
        MockERC20(tokenB).approve(address(basicAMM), type(uint256).max);
        MockERC20(tokenA).approve(address(enhancedAMM), type(uint256).max);
        MockERC20(tokenB).approve(address(enhancedAMM), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        MockERC20(tokenA).approve(address(basicAMM), type(uint256).max);
        MockERC20(tokenB).approve(address(basicAMM), type(uint256).max);
        MockERC20(tokenA).approve(address(enhancedAMM), type(uint256).max);
        MockERC20(tokenB).approve(address(enhancedAMM), type(uint256).max);
        vm.stopPrank();
    }
    
    function testAddLiquidityGasComparison() public {
        console.log("\n=== Add Liquidity Gas Comparison ===");
        
        vm.startPrank(alice);
        
        // Measure Basic AMM
        uint256 gasStart = gasleft();
        basicAMM.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, alice);
        uint256 basicGas = gasStart - gasleft();
        
        // Measure Enhanced AMM
        gasStart = gasleft();
        enhancedAMM.addLiquidityEnhanced(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, alice);
        uint256 enhancedGas = gasStart - gasleft();
        
        vm.stopPrank();
        
        // Report results
        console.log("Basic AMM gas:", basicGas);
        console.log("Enhanced AMM gas:", enhancedGas);
        
        if (enhancedGas < basicGas) {
            uint256 savings = ((basicGas - enhancedGas) * 100) / basicGas;
            console.log("Gas savings:", savings, "%");
        } else {
            uint256 increase = ((enhancedGas - basicGas) * 100) / basicGas;
            console.log("Gas increase:", increase, "%");
        }
    }
    
    function testSwapGasComparison() public {
        // First add liquidity
        vm.startPrank(alice);
        basicAMM.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, alice);
        enhancedAMM.addLiquidityEnhanced(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, alice);
        vm.stopPrank();
        
        console.log("\n=== Swap Gas Comparison ===");
        
        vm.startPrank(bob);
        
        // Measure Basic AMM swap
        uint256 gasStart = gasleft();
        basicAMM.swap(tokenA, SWAP_AMOUNT, 0, bob);
        uint256 basicGas = gasStart - gasleft();
        
        // Measure Enhanced AMM swap
        gasStart = gasleft();
        enhancedAMM.swapEnhanced(tokenA, SWAP_AMOUNT, 0, bob);
        uint256 enhancedGas = gasStart - gasleft();
        
        vm.stopPrank();
        
        // Report results
        console.log("Basic AMM gas:", basicGas);
        console.log("Enhanced AMM gas:", enhancedGas);
        
        if (enhancedGas < basicGas) {
            uint256 savings = ((basicGas - enhancedGas) * 100) / basicGas;
            console.log("Gas savings:", savings, "%");
        }
    }
    
    function testMathEngineDirectly() public {
        console.log("\n=== Direct Math Engine Tests ===");
        
        // Test square root
        uint256 gasStart = gasleft();
        uint256 sqrtResult = mathEngine.calculatePreciseSquareRoot(1000000 * 1e18);
        uint256 sqrtGas = gasStart - gasleft();
        console.log("Square root of 1M tokens:", sqrtResult / 1e9, "(scaled down)");
        console.log("Gas used:", sqrtGas);
        
        // Test dynamic fee calculation
        IMathematicalEngine.DynamicFeeParams memory feeParams = IMathematicalEngine.DynamicFeeParams({
            volatility: 200, // 200 basis points
            volume24h: 1000 * 1e18,
            liquidityDepth: 100000 * 1e18
        });
        
        gasStart = gasleft();
        uint256 dynamicFee = mathEngine.calculateDynamicFee(feeParams);
        uint256 feeGas = gasStart - gasleft();
        console.log("Dynamic fee:", dynamicFee, "basis points");
        console.log("Gas used:", feeGas);
        
        // This would be impossible in pure Solidity!
        console.log("Note: Dynamic fee calculation uses exp/log functions impossible in Solidity");
    }
}

// Mock ERC20 for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        // Mint initial supply to deployer
        totalSupply = 1000000 * 10**18;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
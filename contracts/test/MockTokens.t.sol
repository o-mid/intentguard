// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {MockSwapRouter} from "../src/MockSwapRouter.sol";

contract MockTokensTest is Test {
    MockERC20 internal usdc;
    MockERC20 internal weth;
    MockSwapRouter internal router;

    address internal alice = address(0xA11CE);

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "MOCK_USDC");
        weth = new MockERC20("Mock ETH", "MOCK_ETH");
        // 1 MOCK_USDC -> 0.001 MOCK_ETH
        router = new MockSwapRouter(1e15);

        usdc.mint(alice, 100e18);
        weth.mint(address(router), 1_000e18);
    }

    function test_mint() public view {
        assertEq(usdc.balanceOf(alice), 100e18);
        assertEq(usdc.totalSupply(), 100e18);
    }

    function test_approve_and_allowance() public {
        vm.prank(alice);
        usdc.approve(address(router), 10e18);
        assertEq(usdc.allowance(alice, address(router)), 10e18);
    }

    function test_swap_happy_path() public {
        vm.startPrank(alice);
        usdc.approve(address(router), 10e18);
        uint256 out = router.swap(address(usdc), address(weth), 10e18, 0);
        vm.stopPrank();

        assertEq(out, 0.01e18);
        assertEq(usdc.balanceOf(alice), 90e18);
        assertEq(weth.balanceOf(alice), 0.01e18);
        assertEq(usdc.balanceOf(address(router)), 10e18);
    }

    function test_swap_reverts_without_allowance() public {
        vm.prank(alice);
        vm.expectRevert(bytes("MockERC20: insufficient allowance"));
        router.swap(address(usdc), address(weth), 10e18, 0);
    }
}

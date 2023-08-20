// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Test } from "lib/forge-std/src/Test.sol";
import { DSSTORE2 } from "../src/DSSTORE2.sol";

// reading/writing is tested in SSTORE2.t.sol.
// we only test self-destruct / onlyowner here.

// must abuse the setUp function to test self destruct
// https://github.com/foundry-rs/foundry/issues/1543

contract DSSTORE2Test is Test {
    address pointer;
    bytes testBytes;

    function setUp() public {
        testBytes = abi.encodePacked("this is a test string");
        pointer = DSSTORE2.write(testBytes);
        pointer.call("");
    }

    function testSelfDestruct() public {
        assertEq(pointer.code.length, 0);
    }
}

contract DSSTORE2Test2 is Test {
    address pointer;
    bytes testBytes;
    address alice = address(uint160(1117));

    function setUp() public {
        testBytes = abi.encodePacked("yet another test string");
        pointer = DSSTORE2.write(testBytes);
        vm.prank(alice);
        pointer.call("");
    }

    function testFailSelfDestruct() public {
        assertEq(pointer.code.length, 0);
    }
}

// use balance instead of code.length to test selfdestruct in single tx.
// https://twitter.com/brockjelmore/status/1670112115276005376

contract DSSTORE2TestBalance is Test {
    address pointer;
    bytes testBytes;
    address alice = address(uint160(1117));
    address sender = address(uint160(1111));

    function setUp() public {
        // deploy DSSTORE2
        testBytes = abi.encodePacked("beefy alice");
        pointer = DSSTORE2.write(testBytes);
        // seed with ether
        vm.deal(sender, 1 ether);
        vm.prank(sender);
        payable(pointer).transfer(1 ether);
    }

    function testSelfDestruct() public {
        assertEq(pointer.balance, 1 ether);
        pointer.call("");
        assertEq(pointer.balance, 0);
    }

    function testNotOwner() public {
        assertEq(pointer.balance, 1 ether);
        vm.prank(alice);
        pointer.call("");
        assertEq(pointer.balance, 1 ether);
    }
}

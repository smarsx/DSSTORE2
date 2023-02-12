// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import { Test } from "lib/forge-std/src/Test.sol";
import { DSSTORE2 } from "../src/DSSTORE2.sol";

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

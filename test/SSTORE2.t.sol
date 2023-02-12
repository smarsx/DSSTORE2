// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Test } from "lib/forge-std/src/Test.sol";
import { DSSTORE2 } from "../src/DSSTORE2.sol";

/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/test/SSTORE2.sol)
contract SSTORE2Test is Test {
    address internal constant DEAD_ADDRESS = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

    modifier brutalizeMemory(bytes memory brutalizeWith) {
        /// @solidity memory-safe-assembly
        assembly {
            // Fill the 64 bytes of scratch space with the data.
            pop(
                staticcall(
                    gas(), // Pass along all the gas in the call.
                    0x04, // Call the identity precompile address.
                    brutalizeWith, // Offset is the bytes' pointer.
                    64, // Copy enough to only fill the scratch space.
                    0, // Store the return value in the scratch space.
                    64 // Scratch space is only 64 bytes in size, we don't want to write further.
                )
            )

            let size := add(mload(brutalizeWith), 32) // Add 32 to include the 32 byte length slot.

            // Fill the free memory pointer's destination with the data.
            pop(
                staticcall(
                    gas(), // Pass along all the gas in the call.
                    0x04, // Call the identity precompile address.
                    brutalizeWith, // Offset is the bytes' pointer.
                    size, // We want to pass the length of the bytes.
                    mload(0x40), // Store the return value at the free memory pointer.
                    size // Since the precompile just returns its input, we reuse size.
                )
            )
        }

        _;
    }

    function testWriteRead() public {
        bytes memory testBytes = abi.encode("this is a test");

        address pointer = DSSTORE2.write(testBytes);

        assertEq(DSSTORE2.read(pointer), testBytes);
    }

    function testWriteReadFullStartBound() public {
        assertEq(DSSTORE2.read(DSSTORE2.write(hex"11223344"), 0), hex"11223344");
    }

    function testWriteReadCustomStartBound() public {
        assertEq(DSSTORE2.read(DSSTORE2.write(hex"11223344"), 1), hex"223344");
    }

    function testWriteReadFullBoundedRead() public {
        bytes memory testBytes = abi.encode("this is a test");

        assertEq(DSSTORE2.read(DSSTORE2.write(testBytes), 0, testBytes.length), testBytes);
    }

    function testWriteReadCustomBounds() public {
        assertEq(DSSTORE2.read(DSSTORE2.write(hex"11223344"), 1, 3), hex"2233");
    }

    function testWriteReadEmptyBound() public {
        DSSTORE2.read(DSSTORE2.write(hex"11223344"), 3, 3);
    }

    function testFailReadInvalidPointer() public view {
        DSSTORE2.read(DEAD_ADDRESS);
    }

    function testFailReadInvalidPointerCustomStartBound() public view {
        DSSTORE2.read(DEAD_ADDRESS, 1);
    }

    function testFailReadInvalidPointerCustomBounds() public view {
        DSSTORE2.read(DEAD_ADDRESS, 2, 4);
    }

    function testFailWriteReadOutOfStartBound() public {
        DSSTORE2.read(DSSTORE2.write(hex"11223344"), 41000);
    }

    function testFailWriteReadEmptyOutOfBounds() public {
        DSSTORE2.read(DSSTORE2.write(hex"11223344"), 42000, 42000);
    }

    function testFailWriteReadOutOfBounds() public {
        DSSTORE2.read(DSSTORE2.write(hex"11223344"), 41000, 42000);
    }

    function testWriteRead(bytes calldata testBytes, bytes calldata brutalizeWith)
        public
        brutalizeMemory(brutalizeWith)
    {
        assertEq(DSSTORE2.read(DSSTORE2.write(testBytes)), testBytes);
    }

    function testWriteReadCustomStartBound(
        bytes calldata testBytes,
        uint256 startIndex,
        bytes calldata brutalizeWith
    ) public brutalizeMemory(brutalizeWith) {
        if (testBytes.length == 0) return;

        startIndex = bound(startIndex, 0, testBytes.length);

        assertEq(DSSTORE2.read(DSSTORE2.write(testBytes), startIndex), bytes(testBytes[startIndex:]));
    }

    function testWriteReadCustomBounds(
        bytes calldata testBytes,
        uint256 startIndex,
        uint256 endIndex,
        bytes calldata brutalizeWith
    ) public brutalizeMemory(brutalizeWith) {
        if (testBytes.length == 0) return;

        endIndex = bound(endIndex, 0, testBytes.length);
        startIndex = bound(startIndex, 0, testBytes.length);

        if (startIndex > endIndex) return;

        assertEq(
            DSSTORE2.read(DSSTORE2.write(testBytes), startIndex, endIndex),
            bytes(testBytes[startIndex:endIndex])
        );
    }

    function testFailReadInvalidPointer(address pointer, bytes calldata brutalizeWith)
        public
        view
        brutalizeMemory(brutalizeWith)
    {
        if (pointer.code.length > 0) revert();

        DSSTORE2.read(pointer);
    }

    function testFailReadInvalidPointerCustomStartBound(
        address pointer,
        uint256 startIndex,
        bytes calldata brutalizeWith
    ) public view brutalizeMemory(brutalizeWith) {
        if (pointer.code.length > 0) revert();

        DSSTORE2.read(pointer, startIndex);
    }

    function testFailReadInvalidPointerCustomBounds(
        address pointer,
        uint256 startIndex,
        uint256 endIndex,
        bytes calldata brutalizeWith
    ) public view brutalizeMemory(brutalizeWith) {
        if (pointer.code.length > 0) revert();

        DSSTORE2.read(pointer, startIndex, endIndex);
    }

    function testFailWriteReadCustomStartBoundOutOfRange(
        bytes calldata testBytes,
        uint256 startIndex,
        bytes calldata brutalizeWith
    ) public brutalizeMemory(brutalizeWith) {
        startIndex = bound(startIndex, testBytes.length + 1, type(uint256).max);

        DSSTORE2.read(DSSTORE2.write(testBytes), startIndex);
    }

    function testFailWriteReadCustomBoundsOutOfRange(
        bytes calldata testBytes,
        uint256 startIndex,
        uint256 endIndex,
        bytes calldata brutalizeWith
    ) public brutalizeMemory(brutalizeWith) {
        endIndex = bound(endIndex, testBytes.length + 1, type(uint256).max);

        DSSTORE2.read(DSSTORE2.write(testBytes), startIndex, endIndex);
    }
}

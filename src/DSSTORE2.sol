// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// @notice Read and write to persistent storage at a fraction of the cost. With onlyowner selfdestruct to clear data.
/// @author Modified from solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
/// @author selfdestruct bytecode from (https://github.com/ZeframLou/sstore2/blob/master/contracts/SSTORE3.sol)
library DSSTORE2 {
    error DeployFailed();
    error OutOfBounds();
    uint256 private constant DATA_OFFSET = 30;

    /*//////////////////////////////////////////////////////////////
                               WRITE LOGIC
    //////////////////////////////////////////////////////////////*/

    function write(bytes memory data) internal returns (address pointer) {

        // bytecode of the data-contract. when called, if sender is owner, then selfdestruct, else halt.
        // data stored from 0x09 onwards.
        bytes memory runtimeCode = abi.encodePacked(
            //----------------------------------------------------------------------------------------//
            // Opcode  | Opcode + Arguments                             | Description  | Stack View   //    
            //------------------------------------------------------------------------------------------ 
            // 0x33    |  0x33                                          | CALLER       | owner sender //              
            // 0x73    |  0x73XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  | PUSH20 owner | isOwner      //         
            // 0x14    |  0x14                                          | EQ           | 0x06 isOwner //              
            // 0x60    |  0x601B                                        | PUSH1 0x06   |              // % branch based on isOwner  
            // 0x57    |  0x57                                          | JUMPI        |              // % not owner, halt
            // 0x00    |  0x00                                          | STOP         |              // % is owner, selfdestruct
            // 0x5B    |  0x5B                                          | JUMPDEST     |              // % use tx.origin
            // 0x32    |  0x32                                          | ORIGIN       | origin       //
            // 0xFF    |  0xFF                                          | SELFDESTRUCT |              //
            //----------------------------------------------------------------------------------------//
            hex"33_73",
            address(this),
            hex"14_60_1B_57_00_5B_32_FF",
            data
        );

        bytes memory creationCode = abi.encodePacked(
            //-------------------------------------------------------------------//
            // Opcode  | Opcode + Arguments | Description       | Stack View     //    
            //--------------------------------------------------------------------- 
            // 0x63    |  0x63XXXXXX        | PUSH4 code.length | size           //              
            // 0x80    |  0x80              | DUP1              | size size      //         
            // 0x60    |  0x600e            | PUSH1 14          | 14 size size   //              
            // 0x60    |  0x6000            | PUSH1 00          | 0 14 size size //    
            // 0x39    |  0x39              | CODECOPY          | size           //
            // 0x60    |  0x6000            | PUSH1 00          | 0 size         //  
            // 0xf3    |  0xf3              | RETURN            |                //   
            //-------------------------------------------------------------------//
            hex"63",
            uint32(runtimeCode.length),
            hex"80_60_0E_60_00_39_60_00_F3",
            runtimeCode
        );

        assembly {
            // Deploy a new contract with the generated creation code.
            // We start 32 bytes into the code to avoid copying the byte length.
            pointer := create(0, add(creationCode, 32), mload(creationCode))
        }

        if (pointer == address(0)) revert DeployFailed();
    }

    /*//////////////////////////////////////////////////////////////
                               READ LOGIC
    //////////////////////////////////////////////////////////////*/

    function read(address pointer) internal view returns (bytes memory) {
        return readBytecode(pointer, DATA_OFFSET, pointer.code.length - DATA_OFFSET);
    }

    function read(address pointer, uint256 start) internal view returns (bytes memory) {
        start += DATA_OFFSET;

        return readBytecode(pointer, start, pointer.code.length - start);
    }

    function read(
        address pointer,
        uint256 start,
        uint256 end
    ) internal view returns (bytes memory) {
        start += DATA_OFFSET;
        end += DATA_OFFSET;

        if (pointer.code.length < end) revert OutOfBounds();

        return readBytecode(pointer, start, end - start);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPER LOGIC
    //////////////////////////////////////////////////////////////*/

    function readBytecode(
        address pointer,
        uint256 start,
        uint256 size
    ) private view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            data := mload(0x40)

            // Update the free memory pointer to prevent overriding our data.
            // We use and(x, not(31)) as a cheaper equivalent to sub(x, mod(x, 32)).
            // Adding 31 to size and running the result through the logic above ensures
            // the memory pointer remains word-aligned, following the Solidity convention.
            mstore(0x40, add(data, and(add(add(size, 32), 31), not(31))))

            // Store the size of the data in the first 32 byte chunk of free memory.
            mstore(data, size)

            // Copy the code into memory right after the 32 bytes we used to store the size.
            extcodecopy(pointer, add(data, 32), start, size)
        }
    }
}

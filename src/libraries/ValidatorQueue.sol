// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {DataTypes} from "./DataTypes.sol";
import {Errors} from "./Errors.sol";

library ValidatorQueue {
    // Events
    event ValidatorAdded(bytes pubKey, bytes withdrawalCredential);
    event ValidatorQueueCleared();
    event ValidatorRemoved(bytes pubKey, uint256 removeIndex, bool unordered);
    event ValidatorsPopped(uint256 times);
    event ValidatorsSwapped(
        bytes fromPubKey,
        bytes toPubKey,
        uint256 fromIndex,
        uint256 toIndex
    );

    /**
        @notice Add synced validator in the FIFO queue to be ready for staking
        @param  deque                  DataTypes.ValidatorDeque  Deque
        @param  validator              DataTypes.Validator       Validator
        @param  withdrawalCredentials  bytes                     Credentials
     */
    function add(
        DataTypes.ValidatorDeque storage deque,
        DataTypes.Validator memory validator,
        bytes memory withdrawalCredentials
    ) external {
        int128 backIndex = deque._end;
        deque._validators[backIndex] = validator;

        unchecked {
            deque._end = backIndex + 1;
        }

        emit ValidatorAdded(validator.pubKey, withdrawalCredentials);
    }

    /**
        @notice Swap the location of one validator with another
        @param  deque      DataTypes.ValidatorDeque  Deque
        @param  fromIndex  int128                    From index 
        @param  toIndex    int128                    To index
     */
    function swap(
        DataTypes.ValidatorDeque storage deque,
        uint256 fromIndex,
        uint256 toIndex
    ) public {
        if (fromIndex == toIndex) revert Errors.InvalidIndexRanges();
        if (empty(deque)) revert Errors.ValidatorQueueEmpty();

        int128 fromidx = SafeCast.toInt128(
            int256(deque._begin) + SafeCast.toInt256(fromIndex)
        );

        if (fromidx >= deque._end) revert Errors.OutOfBounds();

        int128 toidx = SafeCast.toInt128(
            int256(deque._begin) + SafeCast.toInt256(toIndex)
        );

        if (toidx >= deque._end) revert Errors.OutOfBounds();

        // Get the original values
        DataTypes.Validator memory fromVal = deque._validators[fromidx];
        DataTypes.Validator memory toVal = deque._validators[toidx];

        // Set the swapped values
        deque._validators[toidx] = fromVal;
        deque._validators[fromidx] = toVal;

        emit ValidatorsSwapped(
            fromVal.pubKey,
            toVal.pubKey,
            fromIndex,
            toIndex
        );
    }

    /**
        @notice Remove validators from the end of queue, in case they were added in error
        @param  deque      DataTypes.ValidatorDeque  Deque
        @param  times      uint256                   Count of pop operations
        @return validator  DataTypes.Validator       Removed and returned validator
     */
    function pop(
        DataTypes.ValidatorDeque storage deque,
        uint256 times
    ) public returns (DataTypes.Validator memory validator) {
        // Loop through and remove validator entries at the end
        for (uint256 _i; _i < times; ) {
            if (empty(deque)) revert Errors.ValidatorQueueEmpty();

            int128 backIndex;

            unchecked {
                backIndex = deque._end - 1;
                ++_i;
            }

            validator = deque._validators[backIndex];
            delete deque._validators[backIndex];
            deque._end = backIndex;
        }

        emit ValidatorsPopped(times);
    }

    /**
        @notice Return whether the deque is empty
        @param  deque  DataTypes.ValidatorDeque  Deque
        @return        bool
     */
    function empty(
        DataTypes.ValidatorDeque storage deque
    ) public view returns (bool) {
        return deque._end <= deque._begin;
    }

    /**
        @notice Remove a validator from the array by more gassy loop
        @param  deque         DataTypes.ValidatorDeque  Deque
        @param  removeIndex   uint256                   Remove index
        @return removedPubKey bytes                     public key
     */
    function removeOrdered(
        DataTypes.ValidatorDeque storage deque,
        uint256 removeIndex
    ) external returns (bytes memory removedPubKey) {
        int128 idx = SafeCast.toInt128(
            int256(deque._begin) + SafeCast.toInt256(removeIndex)
        );

        if (idx >= deque._end) revert Errors.OutOfBounds();

        // Get the pubkey for the validator to remove (for informational purposes)
        removedPubKey = deque._validators[idx].pubKey;

        for (int128 _i = idx; _i < deque._end - 1; ) {
            deque._validators[_i] = deque._validators[_i + 1];

            unchecked {
                ++_i;
            }
        }

        pop(deque, 1);

        emit ValidatorRemoved(removedPubKey, removeIndex, false);
    }

    /**
        @notice Remove a validator from the array by swap and pop
        @param  deque         DataTypes.ValidatorDeque  Deque
        @param  removeIndex   uint256                   Remove index
        @return removedPubkey bytes                     Public key   
     */
    function removeUnordered(
        DataTypes.ValidatorDeque storage deque,
        uint256 removeIndex
    ) external returns (bytes memory removedPubkey) {
        int128 idx = SafeCast.toInt128(
            int256(deque._begin) + SafeCast.toInt256(removeIndex)
        );

        if (idx >= deque._end) revert Errors.OutOfBounds();

        // Get the pubkey for the validator to remove (for informational purposes)
        removedPubkey = deque._validators[idx].pubKey;

        // Swap the (validator to remove) with the last validator in the array if needed
        uint256 lastIndex = count(deque) - 1;
        if (removeIndex != lastIndex) {
            swap(deque, removeIndex, lastIndex);
        }

        // Pop off the validator to remove, which is now at the end of the array
        pop(deque, 1);

        emit ValidatorRemoved(removedPubkey, removeIndex, true);
    }

    /**
        @notice Remove the last validator from the validators array and return its information
        @param  deque                   DataTypes.ValidatorDeque  Deque
        @param  _withdrawalCredentials  bytes                     Credentials
        @return pubKey                  bytes                     Key
        @return withdrawalCredentials   bytes                     Credentials
        @return signature               bytes                     Signature
        @return depositDataRoot         bytes32                   Deposit data root
        @return receiver                address                   account to receive pxEth
     */
    function getNext(
        DataTypes.ValidatorDeque storage deque,
        bytes memory _withdrawalCredentials
    )
        external
        returns (
            bytes memory pubKey,
            bytes memory withdrawalCredentials,
            bytes memory signature,
            bytes32 depositDataRoot,
            address receiver
        )
    {
        if (empty(deque)) revert Errors.ValidatorQueueEmpty();

        int128 frontIndex = deque._begin;
        DataTypes.Validator memory popped = deque._validators[frontIndex];
        delete deque._validators[frontIndex];

        unchecked {
            deque._begin = frontIndex + 1;
        }

        // Return the validator's information
        pubKey = popped.pubKey;
        withdrawalCredentials = _withdrawalCredentials;
        signature = popped.signature;
        depositDataRoot = popped.depositDataRoot;
        receiver = popped.receiver;
    }

    /**
        @notice Return the information of the i'th validator in the registry
        @param  deque                   DataTypes.ValidatorDeque  Deque
        @param  _withdrawalCredentials  bytes                     Credentials
        @param  _index                  uint256                   Index
        @return pubKey                  bytes                     Key
        @return withdrawalCredentials   bytes                     Credentials
        @return signature               bytes                     Signature
        @return depositDataRoot         bytes32                   Deposit data root
        @return receiver                address                   account to receive pxEth
     */
    function get(
        DataTypes.ValidatorDeque storage deque,
        bytes memory _withdrawalCredentials,
        uint256 _index
    )
        external
        view
        returns (
            bytes memory pubKey,
            bytes memory withdrawalCredentials,
            bytes memory signature,
            bytes32 depositDataRoot,
            address receiver
        )
    {
        // int256(deque._begin) is a safe upcast
        int128 idx = SafeCast.toInt128(
            int256(deque._begin) + SafeCast.toInt256(_index)
        );

        if (idx >= deque._end) revert Errors.OutOfBounds();

        DataTypes.Validator memory _v = deque._validators[idx];

        // Return the validator's information
        pubKey = _v.pubKey;
        withdrawalCredentials = _withdrawalCredentials;
        signature = _v.signature;
        depositDataRoot = _v.depositDataRoot;
        receiver = _v.receiver;
    }

    /**
        @notice Empties the validator queue
        @param  deque  DataTypes.ValidatorDeque  Deque
     */
    function clear(DataTypes.ValidatorDeque storage deque) external {
        deque._begin = 0;
        deque._end = 0;

        emit ValidatorQueueCleared();
    }

    /**
        @notice Returns the number of validators
        @param  deque  DataTypes.ValidatorDeque  Deque
        @return        uint256
     */
    function count(
        DataTypes.ValidatorDeque storage deque
    ) public view returns (uint256) {
        // The interface preserves the invariant that begin <= end so we assume this will not overflow.
        // We also assume there are at most int256.max items in the queue.
        unchecked {
            return uint256(int256(deque._end) - int256(deque._begin));
        }
    }
}

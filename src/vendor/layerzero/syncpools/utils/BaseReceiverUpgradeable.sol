// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Base Receiver
 * @dev Base contract for setting the receiver contract
 */
abstract contract BaseReceiverUpgradeable is OwnableUpgradeable {
    struct BaseReceiverStorage {
        address receiver;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.basereceiver)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseReceiverStorageLocation =
        0x487698e326934c06370ca3c28e3bca79fe27d578048e9d42af7fa98f2e481e00;

    function _getBaseReceiverStorage() internal pure returns (BaseReceiverStorage storage $) {
        assembly {
            $.slot := BaseReceiverStorageLocation
        }
    }

    event ReceiverSet(address receiver);

    function __BaseReceiver_init(address receiver) internal onlyInitializing {
        __BaseReceiver_init_unchained(receiver);
    }

    function __BaseReceiver_init_unchained(address receiver) internal onlyInitializing {
        _setReceiver(receiver);
    }

    /**
     * @dev Get the receiver address
     * @return The receiver address
     */
    function getReceiver() public view virtual returns (address) {
        BaseReceiverStorage storage $ = _getBaseReceiverStorage();
        return $.receiver;
    }

    /**
     * @dev Set the receiver address
     * @param receiver The receiver address
     */
    function setReceiver(address receiver) public virtual onlyOwner {
        _setReceiver(receiver);
    }

    /**
     * @dev Internal function to set the receiver address
     * @param receiver The receiver address
     */
    function _setReceiver(address receiver) internal {
        BaseReceiverStorage storage $ = _getBaseReceiverStorage();
        $.receiver = receiver;

        emit ReceiverSet(receiver);
    }
}

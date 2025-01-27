// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Base Messenger
 * @dev Base contract for setting the messenger contract
 */
abstract contract BaseMessengerUpgradeable is OwnableUpgradeable {
    struct BaseMessengerStorage {
        address messenger;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.basemessenger)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseMessengerStorageLocation =
        0x2d365d82646798ae645c4baa2dc2ee228626f61d8b5395bf298ba125a3c6b100;

    function _getBaseMessengerStorage() internal pure returns (BaseMessengerStorage storage $) {
        assembly {
            $.slot := BaseMessengerStorageLocation
        }
    }

    event MessengerSet(address messenger);

    function __BaseMessenger_init(address messenger) internal onlyInitializing {
        __BaseMessenger_init_unchained(messenger);
    }

    function __BaseMessenger_init_unchained(address messenger) internal onlyInitializing {
        _setMessenger(messenger);
    }

    /**
     * @dev Get the messenger address
     * @return The messenger address
     */
    function getMessenger() public view virtual returns (address) {
        BaseMessengerStorage storage $ = _getBaseMessengerStorage();
        return $.messenger;
    }

    /**
     * @dev Set the messenger address
     * @param messenger The messenger address
     */
    function setMessenger(address messenger) public virtual onlyOwner {
        _setMessenger(messenger);
    }

    /**
     * @dev Internal function to set the messenger address
     * @param messenger The messenger address
     */
    function _setMessenger(address messenger) internal {
        BaseMessengerStorage storage $ = _getBaseMessengerStorage();
        $.messenger = messenger;

        emit MessengerSet(messenger);
    }
}

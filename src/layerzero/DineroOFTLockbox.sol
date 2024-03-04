// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { OFTAdapter } from "./oft/OFTAdapter.sol";

/**
 * @title DineroOFTLockbox
 * @dev Adapts pxETH and apxETH tokens on mainnet to the OFT functionality.
 * @author redactedcartel.finance
 */
contract DineroOFTLockbox is OFTAdapter {
    /**
     * @dev Constructor for the OFTAdapter contract.
     * @param _token The address of the ERC-20 token to be adapted.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     */
    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate
    )
        OFTAdapter(_token, _lzEndpoint, _delegate)
    { }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { OFT } from "./oft/OFT.sol";

/**
 * @title DineroOFT
 * @dev A Standard OFT token with minting and burning with access control.
 * @author redactedcartel.finance
 */
contract DineroOFT is OFT {
    /**
     * @notice Constructor to initialize OFT token with access control.
     * @param _name          string   Token name.
     * @param _symbol        string   Token symbol.
     * @param _lzEndpoint    address  LayerZero endpoint address.
     * @param _delegate      address  The delegate capable of making OApp configurations inside of the endpoint.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    )
        OFT(_name, _symbol, _lzEndpoint, _delegate) {}
}

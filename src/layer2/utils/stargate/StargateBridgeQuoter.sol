// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SendParam, OFTReceipt} from "src/vendor/layerzero/oft/interfaces/IOFT.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IStargate} from "src/layer2/interfaces/IStargate.sol";
import {IBridgeQuoter} from "src/layer2/interfaces/IBridgeQuoter.sol";
import {Constants} from "src/layer2/libraries/Constants.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/**
 * @title StargateBridgeQuoter
 * @notice Provides functionality to quote bridge amounts using Stargate.
 */
contract StargateBridgeQuoter is IBridgeQuoter, Ownable {
    using FixedPointMathLib for uint256;

    uint32 public immutable DST_EID;
    uint256 public constant MAX_MARGIN = 10_000; // 1%
    IStargate public stargate;
    uint256 public margin;

    event StargateUpdated(IStargate indexed stargate);
    event MarginUpdated(uint256 margin);

    /**
     * @dev Initializes the contract with the Stargate interface, owner, and destination EID.
     * @param _stargate The Stargate interface.
     * @param _owner The owner address.
     * @param _dstEid The destination EID.
     */
    constructor(
        IStargate _stargate,
        address _owner,
        uint32 _dstEid
    ) Ownable(_owner) {
        stargate = _stargate;
        DST_EID = _dstEid;
    }

    /**
     * @dev Updates the Stargate interface. Only callable by the owner.
     * @param _stargate The new Stargate interface.
     */
    function setStargate(IStargate _stargate) external onlyOwner {
        stargate = _stargate;
        emit StargateUpdated(_stargate);
    }

    /**
     * @dev Sets the margin for fee calculation. Only callable by the owner.
     * @param _margin The new margin value.
     */
    function setMargin(uint256 _margin) external onlyOwner {
        if (_margin > MAX_MARGIN) {
            revert Errors.InvalidAmount();
        }
        margin = _margin;
        emit MarginUpdated(_margin);
    }

    /**
     * @dev Quotes the amount received after bridging through Stargate.
     * @param amountIn The amount to send.
     * @return amount of tokens ACTUALLY debited from the sender in local decimals.
     * @return amount that will be received after bridging.
     */
    function quoteStargate(
        uint256 amountIn
    ) public view returns (uint256, uint256) {
        (, , OFTReceipt memory receipt) = stargate.quoteOFT(
            SendParam({
                dstEid: DST_EID,
                to: bytes32(0),
                amountLD: amountIn,
                minAmountLD: amountIn,
                extraOptions: "",
                composeMsg: "",
                oftCmd: ""
            })
        );

        return (receipt.amountSentLD, receipt.amountReceivedLD);
    }

    /**
     * @dev Returns the amount out after applying the margin.
     * @param tokenIn The input token address (unused in this implementation).
     * @param amountIn The amount to send.
     * @return amount of tokens ACTUALLY debited from the sender in local decimals.
     * @return amount that will be received after applying the margin.
     */
    function getAmountOut(
        address tokenIn,
        uint256 amountIn
    ) external view override returns (uint256, uint256) {
        // unused parameter
        tokenIn;

        (uint256 amountSent, uint256 amountReceivedLD) = quoteStargate(
            amountIn
        );

        return (
            amountSent,
            amountReceivedLD.mulDivDown(
                Constants.FEE_DENOMINATOR - margin,
                Constants.FEE_DENOMINATOR
            )
        );
    }
}

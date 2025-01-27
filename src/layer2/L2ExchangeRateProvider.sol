// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2ExchangeRateProviderUpgradeable} from "src/vendor/layerzero/syncpools/L2/L2ExchangeRateProviderUpgradeable.sol";
import {Constants} from "src/vendor/layerzero/syncpools/libraries/Constants.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title L2ExchangeRateProvider
 * @notice L2 contract for exchange rate (assetsPerShare) and fee calculation
 */
contract L2ExchangeRateProvider is L2ExchangeRateProviderUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /**
     * @notice Get the amount of tokenOut received after conversion
     * @param tokenIn token address used in the deposit
     * @param amountIn amount of tokenIn used in the deposit
     */
    function getPostFeeAmount(
        address tokenIn,
        uint256 amountIn
    ) public view returns (uint256) {
        L2ExchangeRateProviderStorage
            storage $ = _getL2ExchangeRateProviderStorage();
        RateParameters storage rateParameters = $.rateParameters[tokenIn];

        uint256 feeAmount = (amountIn * rateParameters.depositFee) /
            Constants.PRECISION;

        return amountIn - feeAmount;
    }

    /**
     * @notice Get the assets per share of apxETH vault on L1
     */
    function getAssetsPerShare() public view returns (uint256 assetsPerShare) {
        L2ExchangeRateProviderStorage
            storage $ = _getL2ExchangeRateProviderStorage();
        RateParameters storage rateParameters = $.rateParameters[
            Constants.ETH_ADDRESS
        ];

        address rateOracle = rateParameters.rateOracle;

        if (rateOracle == address(0))
            revert L2ExchangeRateProvider__NoRateOracle();

        (uint256 ratio, uint256 lastUpdated) = _getRateAndLastUpdated(
            rateOracle,
            address(0)
        );

        if (lastUpdated + rateParameters.freshPeriod < block.timestamp)
            revert L2ExchangeRateProvider__OutdatedRate();

        return ratio;
    }

    /**
     * @dev Internal function to get rate and last updated time from a rate oracle
     * @param rateOracle Rate oracle contract
     * @return rate The exchange rate in 1e18 precision
     * @return lastUpdated Last updated time
     */
    function _getRateAndLastUpdated(
        address rateOracle,
        address
    ) internal view override returns (uint256 rate, uint256 lastUpdated) {
        (, int256 answer, , uint256 updatedAt, ) = IAggregatorV3(rateOracle)
            .latestRoundData();

        if (answer <= 0) revert Errors.InvalidRate();

        return (uint256(answer), updatedAt);
    }
}

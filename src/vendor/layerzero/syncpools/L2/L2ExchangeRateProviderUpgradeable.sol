// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IL2ExchangeRateProvider} from "../interfaces/IL2ExchangeRateProvider.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title Exchange Rate Provider
 * @dev Provides exchange rate for different tokens against a common quote token
 * The rates oracles are expected to all use the same quote token.
 * For example, if quote is ETH and token is worth 2 ETH, the rate should be 2e18.
 */
abstract contract L2ExchangeRateProviderUpgradeable is OwnableUpgradeable, IL2ExchangeRateProvider {
    struct L2ExchangeRateProviderStorage {
        /**
         * @dev Mapping of token address to rate parameters
         * All rate oracles are expected to return rates with the `18 + decimalsIn - decimalsOut` decimals
         */
        mapping(address => RateParameters) rateParameters;
    }

    /**
     * @dev Rate parameters for a token
     * @param rateOracle Rate oracle contract, providing the exchange rate
     * @param depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
     * @param freshPeriod Fresh period, in seconds
     */
    struct RateParameters {
        address rateOracle;
        uint64 depositFee;
        uint32 freshPeriod;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.l2exchangerateprovider)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L2ExchangeRateProviderStorageLocation =
        0xe04a73ceb6eb109286b5315cfafd156065d9e3fbfa5269d3606a1b3095f3ad00;

    function _getL2ExchangeRateProviderStorage() internal pure returns (L2ExchangeRateProviderStorage storage $) {
        assembly {
            $.slot := L2ExchangeRateProviderStorageLocation
        }
    }

    error L2ExchangeRateProvider__DepositFeeExceedsMax();
    error L2ExchangeRateProvider__OutdatedRate();
    error L2ExchangeRateProvider__NoRateOracle();

    event RateParametersSet(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod);

    function __L2ExchangeRateProvider_init() internal onlyInitializing {}

    function __L2ExchangeRateProvider_init_unchained() internal onlyInitializing {}

    /**
     * @dev Get rate parameters for a token
     * @param token Token address
     * @return parameters Rate parameters
     */
    function getRateParameters(address token) public view virtual returns (RateParameters memory parameters) {
        L2ExchangeRateProviderStorage storage $ = _getL2ExchangeRateProviderStorage();
        return $.rateParameters[token];
    }

    /**
     * @dev Get conversion amount for a token, given an amount in of token it should return the amount out.
     * It also applies the deposit fee.
     * Will revert if:
     * - No rate oracle is set for the token
     * - The rate is outdated (fresh period has passed)
     * @param token Token address
     * @param amountIn Amount in
     * @return amountOut Amount out
     */
    function getConversionAmount(address token, uint256 amountIn)
        public
        view
        virtual
        override
        returns (uint256 amountOut)
    {
        L2ExchangeRateProviderStorage storage $ = _getL2ExchangeRateProviderStorage();
        RateParameters storage rateParameters = $.rateParameters[token];

        address rateOracle = rateParameters.rateOracle;

        if (rateOracle == address(0)) revert L2ExchangeRateProvider__NoRateOracle();

        (uint256 rate, uint256 lastUpdated) = _getRateAndLastUpdated(rateOracle, token);

        if (lastUpdated + rateParameters.freshPeriod < block.timestamp) revert L2ExchangeRateProvider__OutdatedRate();

        uint256 feeAmount = (amountIn * rateParameters.depositFee + Constants.PRECISION_SUB_ONE) / Constants.PRECISION;
        uint256 amountInAfterFee = amountIn - feeAmount;

        amountOut = amountInAfterFee * Constants.PRECISION / rate;

        return amountOut;
    }

    /**
     * @dev Set rate parameters for a token
     * @param token Token address
     * @param rateOracle Rate oracle contract, providing the exchange rate
     * @param depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
     * @param freshPeriod Fresh period, in seconds
     */
    function setRateParameters(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod)
        public
        virtual
        onlyOwner
    {
        _setRateParameters(token, rateOracle, depositFee, freshPeriod);
    }

    /**
     * @dev Internal function to set rate parameters for a token
     * Will revert if:
     * - Deposit fee exceeds 100% (1e18)
     * @param token Token address
     * @param rateOracle Rate oracle contract, providing the exchange rate
     * @param depositFee Deposit fee, in 1e18 precision (e.g. 1e16 for 1% fee)
     * @param freshPeriod Fresh period, in seconds
     */
    function _setRateParameters(address token, address rateOracle, uint64 depositFee, uint32 freshPeriod)
        internal
        virtual
    {
        if (depositFee > Constants.PRECISION) revert L2ExchangeRateProvider__DepositFeeExceedsMax();

        L2ExchangeRateProviderStorage storage $ = _getL2ExchangeRateProviderStorage();
        $.rateParameters[token] = RateParameters(rateOracle, depositFee, freshPeriod);

        emit RateParametersSet(token, rateOracle, depositFee, freshPeriod);
    }

    /**
     * @dev Internal function to get rate and last updated time from a rate oracle
     * @param rateOracle Rate oracle contract
     * @param token The token address which the rate is for
     * @return rate The exchange rate in 1e18 precision
     * @return lastUpdated Last updated time
     */
    function _getRateAndLastUpdated(address rateOracle, address token)
        internal
        view
        virtual
        returns (uint256 rate, uint256 lastUpdated);
}

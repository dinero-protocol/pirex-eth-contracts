// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessagingFee} from "src/vendor/layerzero/oft/interfaces/IOFT.sol";
import {IBridgeAdapter} from "src/layer2/interfaces/IBridgeAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "src/layer2/libraries/Constants.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title OFTMinter
 * @notice A contract for minting OFT tokens on the destination chain.
 * @dev This contract allows users to deposit tokens on the source chain and mint OFT tokens on the destination chain using a hub chain to where LiquidStakingToken is deployed.
 * @author dinero.xyz
 */
contract OFTMinter is Ownable {
    using SafeERC20 for IERC20;

    IBridgeAdapter public adapter;
    address public lockbox;
    mapping(uint32 => bool) public whiteListedEid;

    event WhitelistedEid(uint32 indexed eid, bool whitelisted);
    event AdapterSet(address adapter);
    event LockboxSet(address lockbox);
    event Deposit(
        address indexed sender,
        uint32 indexed dstEid,
        address indexed receiver,
        address tokenIn,
        uint256 amountIn
    );

    constructor(address _adapter, address _lockbox) Ownable(msg.sender) {
        adapter = IBridgeAdapter(_adapter);
        lockbox = _lockbox;
    }

    /**
     * @notice Deposits tokens to the destination chain.
     * @param _dstEid Destination chain endpoint identifier
     * @param _receiver Address of the receiver
     * @param _tokenIn Address of the token to deposit
     * @param _amountIn Amount of tokens deposited in local decimals
     */
    function deposit(
        uint32 _dstEid,
        address _receiver,
        address _tokenIn,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) public payable {
        if (!whiteListedEid[_dstEid]) revert Errors.UnsupportedEid();
        if (_receiver == address(0)) revert Errors.ZeroAddress();

        if (_tokenIn != Constants.ETH_ADDRESS) {
            IERC20(_tokenIn).safeTransferFrom(
                msg.sender,
                address(adapter),
                _amountIn
            );
        }

        bytes memory data = abi.encode(
            _dstEid,
            bytes32(0x0), // not used
            _receiver,
            _amountIn,
            _minAmountOut
        );

        adapter.sendMessage{value: msg.value}(
            lockbox,
            _tokenIn,
            msg.sender,
            data,
            0
        );

        emit Deposit(msg.sender, _dstEid, _receiver, _tokenIn, _amountIn);
    }

    /**
     * @notice Provides a quote for the send() operation.
     * @param _receiver Address of the receiver
     * @param _tokenIn Address of the token to send
     * @param _amountIn Amount of tokens sent in local decimals
     * @param _amountOut Amount of tokens received in local decimals
     * @return expectedAmountReceived The expected amount to be received.
     * @return fee The calculated LayerZero messaging fee from the send() operation.
     *
     * @dev MessagingFee: LayerZero msg fee
     *  - nativeFee: The native fee.
     *  - lzTokenFee: The lzToken fee.
     */
    function quoteSend(
        uint32 _dstEid,
        address _receiver,
        address _tokenIn,
        uint256 _amountIn,
        uint256 _amountOut
    )
        public
        view
        returns (uint256 expectedAmountReceived, MessagingFee memory fee)
    {
        if (!whiteListedEid[_dstEid]) revert Errors.UnsupportedEid();
        if (_receiver == address(0)) revert Errors.ZeroAddress();

        (expectedAmountReceived, fee) = adapter.quoteSend(
            _dstEid,
            lockbox,
            _tokenIn,
            _amountIn,
            _amountOut
        );
    }

    /**
     * @notice Sets the whitelisted status for a specified destination chain.
     * @dev    This function is used to whitelist or unwhitelist a destination chain.
     *         If the final destination chain is not set or does not exist once the transaction reaches
     *         the first destination chain, the LST will be minted to the user on the first destination chain.
     * @param  _eid          uint32   The endpoint identifier (EID) of the destination chain to set the whitelisted status for.
     * @param  _whitelisted  bool     Boolean value indicating whether the destination chain should be whitelisted.
     */
    function setWhiteListedEid(
        uint32 _eid,
        bool _whitelisted
    ) public onlyOwner {
        whiteListedEid[_eid] = _whitelisted;

        emit WhitelistedEid(_eid, _whitelisted);
    }

    /**
     * @notice Sets the adapter contract address.
     * @dev    This function is used to set the adapter contract address.
     * @param  _adapter  address  The address of the adapter contract.
     */
    function setAdapter(address _adapter) public onlyOwner {
        adapter = IBridgeAdapter(_adapter);

        emit AdapterSet(_adapter);
    }

    /**
     * @notice Sets the lockbox address.
     * @dev    This function is used to set the lockbox address.
     * @param  _lockbox  address  The address of the lockbox.
     */
    function setLockbox(address _lockbox) public onlyOwner {
        lockbox = _lockbox;

        emit LockboxSet(_lockbox);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LiquidStakingTokenLockboxCompose} from "src/layer2/LiquidStakingTokenLockboxCompose.sol";
import {MessagingFee} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {MsgCodec} from "src/layer2/libraries/MsgCodec.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";

/**
 * @title  MuiltichainLockbox
 * @notice An OApp contract for handling LiquidStakingToken operations between mainnet and L2.
 * @dev    This contract is responsible for handling deposits of LiquidStakingTokens between mainnet and L2s.
 * @author redactedcartel.finance
 */
contract MultichainLockbox is LiquidStakingTokenLockboxCompose {
    /// @custom:storage-location erc7201:redacted.storage.LiquidStakingTokenLockbox
    struct MultichainLockboxStorage {
        address oftLockbox;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.MultichainLiquidStakingTokenLockbox)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MultichainLockboxStorageLocation =
        0x897e2bd6d2b1fdc2f2eafe3d01dc261c27476164ef4fd48c6a72614cdf731b00;

    /**
     * @notice Contract constructor to initialize LiquidStakingTokenLockboxCompose with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenLockboxCompose contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _dstEid     uint32   The destination endpoint ID for L2.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _endpoint,
        uint32 _dstEid
    ) LiquidStakingTokenLockboxCompose(_endpoint, _dstEid) {}

    function _getMultichainLockboxStorage()
        private
        pure
        returns (MultichainLockboxStorage storage $)
    {
        assembly {
            $.slot := MultichainLockboxStorageLocation
        }
    }

    event OFTLockboxSet(address oftLockbox);

    /**
     * @notice Perform deposit via AutoPxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable override nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handleEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _sendDeposit(
            _dstEid,
            _receiver,
            _refundAddress,
            _amount,
            amount,
            assetsPerShare,
            _shouldWrap,
            true,
            _options
        );

        emit Deposit(
            _dstEid,
            receipt,
            msg.sender,
            _receiver,
            address(0),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform deposit via PxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param  _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositPxEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable override nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handlePxEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _sendDeposit(
            _dstEid,
            _receiver,
            _refundAddress,
            _amount,
            amount,
            assetsPerShare,
            _shouldWrap,
            false,
            _options
        );

        emit Deposit(
            _dstEid,
            receipt,
            msg.sender,
            _receiver,
            address(getTokenOut()),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform deposit via ApxETH and then relaying the message to L2.
     * @dev    Accept apxEth deposits to be stored in the vault as well as sending message to L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount (in shares).
     * @param  _options   bytes    Additional options for the message.
     */
    function depositApxEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable override nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handleApxEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _sendDeposit(
            _dstEid,
            _receiver,
            _refundAddress,
            _amount,
            amount,
            assetsPerShare,
            _shouldWrap,
            false,
            _options
        );

        emit Deposit(
            _dstEid,
            receipt,
            msg.sender,
            _receiver,
            address(getTokenOut()),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Set the OFTLockbox contract address.
     * @param oftLockbox The address of the OFTLockbox contract.
     */
    function setOFTLockbox(address oftLockbox) external onlyOwner {
        _getMultichainLockboxStorage().oftLockbox = oftLockbox;

        emit OFTLockboxSet(oftLockbox);
    }

    /**
     * @notice Encode the compose message.
     * @param _dstEid The destination endpoint ID.
     * @param _lockbox The address of the lockbox.
     * @param _receiver The address of the receiver.
     * @param _guid The GUID.
     * @param _amountIn The amount in.
     * @param _amountOut The amount out.
     */
    function _encodeComposeMsg(
        uint32 _dstEid,
        address _lockbox,
        address _receiver,
        bytes32 _guid,
        uint256 _amountIn,
        uint256 _amountOut
    ) internal pure virtual returns (bytes memory) {
        return
            abi.encode(
                bytes32(uint256(uint160(_lockbox))),
                _dstEid,
                _guid,
                _receiver,
                _amountIn,
                _amountOut
            );
    }

    /**
     * @notice send deposit to the destination endpoint.
     * @param _dstEid           uint32 The destination endpoint ID.
     * @param _receiver         address The address of the receiver.
     * @param _refundAddress    address The address to receive any excess funds sent to layer zero.
     * @param _depositAmount    uint256 The deposit amount.
     * @param _receivedAmount   uint256 The received amount.
     * @param _assetsPerShare   uint256 The assets per share.
     * @param _shouldWrap       bool Whether to wrap rebase token on destination chain.
     * @param _ethDeposit       bool Whether the deposit is in ETH.
     * @param _options          bytes Additional options for the message.
     */
    function _sendDeposit(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _depositAmount,
        uint256 _receivedAmount,
        uint256 _assetsPerShare,
        bool _shouldWrap,
        bool _ethDeposit,
        bytes calldata _options
    ) internal returns (bytes32 receipt) {
        address oftLockbox = _getMultichainLockboxStorage().oftLockbox;

        if (_dstEid != L2_EID) {
            if (_shouldWrap) revert Errors.MultichainDepositsCannotBeWrapped();

            receipt = _send(
                _encodeDeposit(
                    _receivedAmount,
                    _assetsPerShare,
                    oftLockbox,
                    _shouldWrap
                ),
                _encodeComposeMsg(
                    _dstEid,
                    oftLockbox,
                    _receiver,
                    bytes32(0x0), // not used
                    _depositAmount,
                    _receivedAmount
                ),
                _options,
                _ethDeposit ? msg.value - _depositAmount : msg.value,
                _refundAddress
            );
        } else {
            receipt = _send(
                _encodeDeposit(
                    _receivedAmount,
                    _assetsPerShare,
                    _receiver,
                    _shouldWrap
                ),
                "",
                _options,
                _ethDeposit ? msg.value - _depositAmount : msg.value,
                _refundAddress
            );
        }
    }

    /**
     * @notice Quote gas cost for multichain deposit messages
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _amount    uint256  Deposit amount.
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteMultichainDeposit(
        address _receiver,
        uint256 _amount,
        bytes calldata _options
    ) external view returns (MessagingFee memory msgFee) {
        return
            _quote(
                L2_EID,
                MsgCodec.encode(
                    abi.encode(
                        1,
                        _amount, // Use amount directly for quote
                        uint256(1e18),
                        _receiver,
                        _syncedIdsBatch()
                    ),
                    abi.encode(
                        bytes32(uint256(uint160(address(this)))),
                        L2_EID,
                        bytes32(uint256(1)),
                        _receiver,
                        uint256(1e18),
                        uint256(1e18)
                    )
                ),
                combineOptions(L2_EID, 0, _options),
                false
            );
    }
}

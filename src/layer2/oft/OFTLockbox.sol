// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OFTAdapterUpgradeable} from "src/vendor/layerzero-upgradeable/oft/OFTAdapterUpgradeable.sol";
import {IWrappedLiquidStakedToken} from "src/layer2/interfaces/IWrappedLiquidStakedToken.sol";
import {ILiquidStakingToken} from "src/layer2/interfaces/ILiquidStakingToken.sol";
import {OFTComposeMsgCodec} from "src/vendor/layerzero/oft/libs/OFTComposeMsgCodec.sol";
import {Constants} from "src/layer2/libraries/Constants.sol";
import {Origin} from "src/vendor/layerzero/protocol/interfaces/ILayerZeroReceiver.sol";
import {SendParam, MessagingFee} from "src/vendor/layerzero/oft/interfaces/IOFT.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title OFTLockbox
 * @notice The OFTLockbox contract is responsible to hold wLST tokens and mint wLST OFTs on the destination chain.
 * @dev This contract allows users to deposit tokens on the source chain and mint wrapped liquid staking OFTs on the destination chain using a hub chain to where LiquidStakingToken is deployed.
 * @author dinero.xyz
 */
contract OFTLockbox is OFTAdapterUpgradeable {
    using OFTComposeMsgCodec for bytes;
    using SafeERC20 for IERC20;

    uint32 private immutable MAINNET_EID;

    event ComposeCallerSet(address indexed caller, bool allowed);
    event OriginCallerSet(uint32 indexed eid, bytes32 origin);

    /// @custom:storage-location erc7201:dinero.storage.OFTLockbox
    struct OFTLockboxStorage {
        mapping(address => bool) composeCaller;
        mapping(uint32 => bytes32) originCaller;
    }

    // keccak256(abi.encode(uint256(keccak256(dinero.storage.OFTLockbox)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OFTLockboxStorageLocation =
        0x8ae44db288e31ea573bddaa9dde3a720f6640e58cec08015e9f303260773b300;

    function _getLiquidStakingTokenStorage()
        internal
        pure
        returns (OFTLockboxStorage storage $)
    {
        assembly {
            $.slot := OFTLockboxStorageLocation
        }
    }

    /**
     * @dev Constructor for the OFTAdapter contract.
     * @param _token The address of the ERC-20 token to be adapted.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _mainnetEid The mainnet endpoint ID.
     */
    constructor(
        address _token,
        address _lzEndpoint,
        uint32 _mainnetEid
    ) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        MAINNET_EID = _mainnetEid;
        _disableInitializers();
    }

    /**
     * @dev Initializes the OFTLockbox.
     * @dev The delegate typically should be set as the admin of the contract.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     * @param _owner The owner of the contract.
     */
    function initialize(
        address _delegate,
        address _owner
    ) external initializer {
        if (_delegate == address(0) || _owner == address(0)) {
            revert Errors.ZeroAddress();
        }
        __OFTAdapter_init(_delegate);
        __Ownable_init(_owner);
    }

    /**
     * @notice Sets the compose caller.
     * @param _caller The address of the compose caller.
     * @param _allowed The boolean value to set the compose caller.
     */
    function setComposeCaller(
        address _caller,
        bool _allowed
    ) external onlyOwner {
        OFTLockboxStorage storage $ = _getLiquidStakingTokenStorage();
        $.composeCaller[_caller] = _allowed;

        emit ComposeCallerSet(_caller, _allowed);
    }

    /**
     * @notice Sets the origin caller.
     * @param _eid The endpoint ID.
     * @param _origin The origin caller.
     */
    function setOriginCaller(uint32 _eid, bytes32 _origin) external onlyOwner {
        OFTLockboxStorage storage $ = _getLiquidStakingTokenStorage();
        $.originCaller[_eid] = _origin;

        emit OriginCallerSet(_eid, _origin);
    }

    /**
     * @notice Composes a LayerZero message from an OApp.
     * @param _from The address initiating the composition, typically the OApp where the lzReceive was called.
     * @param _message The composed message payload in bytes. NOT necessarily the same payload passed via lzReceive.
     */
    function lzCompose(
        address _from,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) external payable {
        // only endpoint
        if (msg.sender != address(endpoint)) revert OnlyEndpoint(msg.sender);

        OFTLockboxStorage storage $ = _getLiquidStakingTokenStorage();

        uint32 srcEid = _message.srcEid();
        bytes32 composeFrom = _message.composeFrom();
        // only peer
        if ($.originCaller[srcEid] != composeFrom)
            revert OnlyPeer(srcEid, composeFrom);

        // only allowed compose caller
        if (!$.composeCaller[_from]) revert Errors.NotAllowed();

        bytes memory _composeMessage = _message.composeMsg();
        (uint32 dstEid, , address receiver, , uint256 amountOut) = abi.decode(
            _composeMessage,
            (uint32, bytes32, address, uint256, uint256)
        );

        address lst = IWrappedLiquidStakedToken(address(innerToken))
            .getLSTAddress();

        uint256 lstAmount = amountOut;
        if (srcEid != MAINNET_EID) {
            lstAmount = ILiquidStakingToken(lst).deposit{value: amountOut}(
                Constants.ETH_ADDRESS,
                amountOut,
                amountOut
            );
        }

        IERC20(lst).approve(address(innerToken), lstAmount);

        uint256 wlstAmount = IWrappedLiquidStakedToken(address(innerToken))
            .wrap(lstAmount);

        if (endpoint.eid() == dstEid) {
            innerToken.safeTransfer(receiver, wlstAmount);
        } else {
            _lzSend(
                dstEid,
                abi.encodePacked(receiver, _toSD(wlstAmount)),
                _getOAppOptionsType3Storage().enforcedOptions[dstEid][SEND],
                MessagingFee(msg.value, 0),
                receiver
            );
        }
    }

    /**
     * @notice Withdraws ETH from the contract.
     * @param _amount The amount to withdraw.
     */
    function withdraw(uint256 _amount) external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) revert Errors.NativeTransferFailed();
    }

    receive() external payable {}
}

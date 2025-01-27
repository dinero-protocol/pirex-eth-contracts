// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessagingFee, MessagingReceipt, SendParam, OFTReceipt} from "src/vendor/layerzero/oft/interfaces/IOFT.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStargate} from "src/layer2/interfaces/IStargate.sol";
import {Constants} from "src/layer2/libraries/Constants.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";

contract StargateAdapter is Ownable {
    using SafeERC20 for IERC20;

    uint32 public immutable DST_EID;
    IStargate public stargate;
    address public l2SyncPool;
    mapping(address => bool) public tokens;
    mapping(address => uint256) public refunds;
    mapping(uint32 => bytes) public lzComposeOptions;

    error MissingLzComposeOptions();

    //events
    event Token(address token, bool whitelisted);
    event Withdraw(address token, uint256 amount);
    event RefundWithdraw(address receiver, uint256 amount);
    event Stargate(address stargate);
    event L2SyncPool(address l2SyncPool);
    event EidLzComposeOptionSet(uint32 eid, bytes extraOptions);

    constructor(
        address _stargate,
        address _l2SyncPool,
        uint32 _dstEid
    ) Ownable(msg.sender) {
        _setStargate(_stargate);
        _setL2SyncPool(_l2SyncPool);
        DST_EID = _dstEid;
    }

    modifier onlySyncPool() {
        if (msg.sender != l2SyncPool) revert Errors.UnauthorizedCaller();
        _;
    }

    /**
     * @notice Whitelist a token to be used in the bridge
     * @param _token address of the token to whitelist
     */
    function whitelistToken(address _token) external onlyOwner {
        tokens[_token] = true;
        if (_token != Constants.ETH_ADDRESS) {
            IERC20(_token).forceApprove(address(stargate), type(uint256).max);
        }

        emit Token(_token, true);
    }

    /**
     * @notice Remove a token from the whitelist
     * @param _token address of the token to remove
     */
    function removeToken(address _token) external onlyOwner {
        tokens[_token] = false;
        if (_token != Constants.ETH_ADDRESS) {
            IERC20(_token).forceApprove(address(stargate), 1);
        }

        emit Token(_token, false);
    }

    /**
     * @notice Set the stargate pool contract
     * @param _stargate address of the stargate contract
     */
    function setStargate(address _stargate) external onlyOwner {
        _setStargate(_stargate);

        emit Stargate(_stargate);
    }

    /**
     * @notice Withdraw tokens from the contract
     * @param _token address of the token to withdraw
     * @param _amount amount to withdraw
     */
    function withdraw(address _token, uint256 _amount) external onlyOwner {
        if (_token == Constants.ETH_ADDRESS) {
            (bool success, ) = payable(msg.sender).call{value: _amount}("");
            if (!success) revert Errors.NativeTransferFailed();
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }

        emit Withdraw(_token, _amount);
    }

    /**
     * @notice Set the L2 sync pool
     * @param _l2SyncPool address of the L2 sync pool
     */
    function setL2SyncPool(address _l2SyncPool) external onlyOwner {
        _setL2SyncPool(_l2SyncPool);

        emit L2SyncPool(_l2SyncPool);
    }

    /**
     * @notice Add executor lzComposeOption
     * @param _eid destination endpoint id
     * @param _extraOptions extra options for the lzCompose
     */
    function addEidLzComposeOption(
        uint32 _eid,
        bytes memory _extraOptions
    ) external onlyOwner {
        lzComposeOptions[_eid] = _extraOptions;

        emit EidLzComposeOptionSet(_eid, _extraOptions);
    }

    /**
     * @notice Prepare the transaction to be sent
     * @param _amountLD Amount of tokens sent in local decimals
     * @param _minAmountLD Amount of tokens received in local decimals
     * @param _receiver Address of the receiver
     * @param _composeMsg Message to be sent
     * @param _extraOptions Extra options for the sendToken() operation
     * @param _revertOnInsufficientOutput Revert if the output is less than the minAmountLD
     * @return valueToSend Value to send to the stargate
     * @return expectedAmountReceived Expected amount to be received
     * @return sendParam The parameters for the sendToken() operation
     * @return messagingFee The fee information
     */
    function prepareTransaction(
        uint256 _amountLD,
        uint256 _minAmountLD,
        address _receiver,
        bytes memory _composeMsg,
        bytes memory _extraOptions,
        bool _revertOnInsufficientOutput
    )
        internal
        view
        returns (
            uint256 valueToSend,
            uint256 expectedAmountReceived,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        )
    {
        if (_extraOptions.length == 0) {
            revert MissingLzComposeOptions();
        }

        sendParam = SendParam({
            dstEid: DST_EID,
            to: bytes32(uint256(uint160(_receiver))),
            amountLD: _amountLD,
            minAmountLD: _minAmountLD,
            extraOptions: _extraOptions,
            composeMsg: _composeMsg,
            oftCmd: new bytes(0)
        });

        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);

        if (
            receipt.amountReceivedLD < _minAmountLD &&
            _revertOnInsufficientOutput
        ) {
            revert Errors.InsufficientAmountOut();
        }

        messagingFee = stargate.quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;
        expectedAmountReceived = receipt.amountReceivedLD;

        if (stargate.token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    /**
     * @notice Send a message to the destination chain
     * @param _receiver Address of the receiver
     * @param _l2token Address of the token to send
     * @param _message Message to be sent
     * @return msgReceipt Messaging receipt
     * @return oftReceipt OFT receipt
     */
    function sendMessage(
        address _receiver,
        address _l2token,
        address _sender,
        bytes memory _message,
        uint32
    )
        public
        payable
        onlySyncPool
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        (uint32 dstEid, , , uint256 amountIn, uint256 amountOut) = abi.decode(
            _message,
            (uint32, bytes32, address, uint256, uint256)
        );

        if (!tokens[_l2token]) revert Errors.UnauthorizedToken();

        (
            uint256 valueToSend,
            ,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = prepareTransaction(
                amountIn,
                amountOut,
                _receiver,
                _message,
                lzComposeOptions[dstEid],
                true
            );

        if (msg.value < valueToSend) revert Errors.InvalidAmount();

        (msgReceipt, oftReceipt, ) = stargate.sendToken{value: valueToSend}(
            sendParam,
            messagingFee,
            _sender
        );

        if (msg.value > valueToSend) {
            refunds[_sender] += (msg.value - valueToSend);
        }
    }

    /**
     * @notice Withdraw the refund
     * @dev The refund paid to the sync keepers is the difference between the value sent
     * and the actual value used in the stargate.sendToken() operation.
     */
    function withdrawRefund() external {
        uint256 refund = refunds[msg.sender];
        if (refund == 0) return;
        refunds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: refund}("");
        if (!success) revert Errors.NativeTransferFailed();

        emit RefundWithdraw(msg.sender, refund);
    }

    /**
     * @notice Provides a quote for the send() operation.
     * @param _receiver Address of the receiver
     * @param _tokenIn Address of the token to send
     * @param _amountIn Amount of tokens sent in local decimals
     * @param _amountOut Amount of tokens received in local decimals
     * @return expectedAmountReceived The expected amount to be received.
     * @return messagingFee The calculated LayerZero messaging fee from the send() operation.
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
        external
        view
        returns (
            uint256 expectedAmountReceived,
            MessagingFee memory messagingFee
        )
    {
        if (!tokens[_tokenIn]) revert Errors.UnauthorizedToken();

        bytes memory data = abi.encode(
            DST_EID,
            bytes32(0x0),
            _tokenIn,
            _amountIn,
            _amountOut
        );

        (, expectedAmountReceived, , messagingFee) = prepareTransaction(
            _amountIn,
            _amountOut,
            _receiver,
            data,
            lzComposeOptions[_dstEid],
            false
        );

        return (expectedAmountReceived, messagingFee);
    }

    /**
     * @notice Set the L2 sync pool
     * @param _l2SyncPool address of the L2 sync pool
     */
    function _setL2SyncPool(address _l2SyncPool) internal {
        if (_l2SyncPool == address(0)) revert Errors.ZeroAddress();
        l2SyncPool = _l2SyncPool;
    }

    /**
     * @notice Set the stargate pool contract
     * @param _stargate address of the stargate contract
     */
    function _setStargate(address _stargate) internal {
        if (_stargate == address(0)) revert Errors.ZeroAddress();
        stargate = IStargate(_stargate);
    }
}

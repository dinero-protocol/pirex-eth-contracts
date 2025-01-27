// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract Oracle is AccessControl {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    struct Answer {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    Answer private _latestAnswer;

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        Answer storage a = _latestAnswer;

        return (
            a.roundId,
            a.answer,
            a.startedAt,
            a.updatedAt,
            a.answeredInRound
        );
    }

    function setAnswer(int256 _answer) external onlyRole(KEEPER_ROLE) {
        Answer storage answer = _latestAnswer;

        answer.answeredInRound = answer.roundId++;
        answer.answer = _answer;
        answer.startedAt = block.timestamp;
        answer.updatedAt = block.timestamp;
    }
}

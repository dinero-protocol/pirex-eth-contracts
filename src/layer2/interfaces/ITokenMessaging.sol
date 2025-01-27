// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

struct BusQueue {
    uint8 maxNumPassengers; // set by the owner
    uint80 busFare; // set by the planner
    uint80 busAndNativeDropFare; // set by the planner
    uint16 qLength; // the length of the queue, i.e. how many passengers are queued up
    uint72 nextTicketId; // the last ticketId driven + 1, so the next ticketId to be driven
}

interface ITokenMessaging {
    function busQueues(uint32) external view returns (BusQueue memory);
}
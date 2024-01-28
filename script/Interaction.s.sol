// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {ConfigHelper} from "./ConfigHelper.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingCfg() public returns (uint64) {
        ConfigHelper configHelper = new ConfigHelper();
        (, , address vrfCoordinator, , , , , uint deployerKey) = configHelper
            .activeNetworkCfg();

        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint deployerKey
    ) public returns (uint64) {
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("SubId", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingCfg();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function funcSubscriptionUsingCfg() public {
        ConfigHelper configHelper = new ConfigHelper();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint deployerKey
        ) = configHelper.activeNetworkCfg();

        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint deployerKey
    ) public {
        console.log("Funding sub", subId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On chainID", block.chainid);

        vm.startBroadcast(deployerKey);
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
        } else {
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
        }
        vm.stopBroadcast();
    }

    function run() external {
        funcSubscriptionUsingCfg();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint deployerKey
    ) public {
        console.log("Adding customer contract", raffle);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On chainID", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingCfg(address raffle) public {
        ConfigHelper configHelper = new ConfigHelper();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint deployerKey
        ) = configHelper.activeNetworkCfg();

        addConsumer(raffle, vrfCoordinator, subId, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingCfg(raffle);
    }
}

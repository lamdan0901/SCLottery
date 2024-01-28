// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {ConfigHelper} from "./ConfigHelper.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../script/Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, ConfigHelper) {
        ConfigHelper configHelper = new ConfigHelper();
        (
            uint entranceFee,
            uint interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint deployerKey
        ) = configHelper.activeNetworkCfg();

        // Check if subscriptionId is 0, if so, create one and fund it
        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            subscriptionId = createSub.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );

        return (raffle, configHelper);
    }
}

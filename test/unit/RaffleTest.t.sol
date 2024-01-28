// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {ConfigHelper} from "../../script/ConfigHelper.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    ConfigHelper configHelper;

    uint entranceFee;
    uint interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, configHelper) = deployRaffle.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = configHelper.activeNetworkCfg();

        // Initially the balance of USER will be zero.
        // Use deal() to provide fake ETH to user.
        // Otherwise, it could lead to "EvmError: OutOfFund"
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    // ---modifiers---
    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) return;
        _;
    }

    // -----

    // function testRaffleInitInOpenState() public view {
    //     assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    // }

    // function testRaffleReversionWhenNotPayingEnough() public {
    //     vm.prank(PLAYER);
    //     vm.expectRevert(Raffle.Raffle_NotEnoughEth.selector);
    //     raffle.enterRaffle();
    // }

    // function testRaffleRecordsPlayersWhenTheyEnter() public {
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    //     address recordedPlayer = raffle.getPlayer(0);
    //     assert(recordedPlayer == PLAYER);
    // }

    // function testEmitsEventOnEntrace() public {
    //     vm.prank(PLAYER);
    //     vm.expectEmit(true, false, false, false, address(raffle));
    //     emit Raffle.EnteredRaffle(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    // }

    // function testCantEnterWhenRaffleIsCalculating()
    //     public
    //     raffleEnteredAndTimePassed
    // {
    //     raffle.performUpkeep("");

    //     vm.expectRevert(Raffle.Raffle_NotOpen.selector);
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    // }

    // function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);

    //     (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    //     assert(!upkeepNeeded);
    // }

    // function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
    //     public
    //     raffleEnteredAndTimePassed
    // {
    //     raffle.performUpkeep("");

    //     (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    //     assert(!upkeepNeeded);
    // }

    // function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
    //     public
    //     raffleEnteredAndTimePassed
    // {
    //     raffle.performUpkeep("");
    //     // There is no expect no revert, so we just stop here
    // }

    // ! failed on sepolia cuz my address doesn't have balance = 0
    // function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public skipFork {
    //     uint currentBalance = 0;
    //     uint numPlayers = 0;
    //     Raffle.RaffleState raffleState = raffle.getRaffleState();

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             Raffle.Raffle_UpkeepNotNeeded.selector,
    //             currentBalance,
    //             numPlayers,
    //             raffleState
    //         )
    //     );
    //     raffle.performUpkeep("");
    // }

    // Test using output of an event
    // function testPerformUpkeepUpdatesRaffleStateAndEmitsReqId()
    //     public
    //     raffleEnteredAndTimePassed
    // {
    //     vm.recordLogs(); // start recording all emitted events
    //     raffle.performUpkeep(""); // reqId is emitted here
    //     Vm.Log[] memory logs = vm.getRecordedLogs(); // save the recorded logs
    //     bytes32 reqId = logs[1].topics[1]; // It's logs[1], not logs[0] cuz another event is emitted in the VRFCoordinatorV2Mock

    //     Raffle.RaffleState raffleState = raffle.getRaffleState();
    //     assert(uint(reqId) > 0);
    //     assert(raffleState == Raffle.RaffleState.CALCULATING);
    // }

    // we pass uint randomReqId as a param here so forge can make a fuzzy test (with many random reqId values)
    // using skipFork() here for other networks but local cuz VRFCoordinatorV2 requires Proof and RequestCommitment
    // function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
    //     uint randomReqId
    // ) public raffleEnteredAndTimePassed skipFork {
    //     vm.expectRevert("nonexistent request");
    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
    //         randomReqId,
    //         address(raffle)
    //     );
    // }

    // using skipFork() here for other networks but local cuz we are not on actual Chainlink network
    // function testFulfillRandomWordsPicksAWinnerThenResetAndSendsMoney()
    //     public
    //     raffleEnteredAndTimePassed
    //     skipFork
    // {
    //     uint additionalEntrants = 5;
    //     uint startingIdx = 1;
    //     for (
    //         uint256 i = startingIdx;
    //         i < startingIdx + additionalEntrants;
    //         i++
    //     ) {
    //         address player = address(uint160(i)); // or makeAddr("player");
    //         hoax(player, STARTING_USER_BALANCE); // create a player with the given address and init balance
    //         raffle.enterRaffle{value: entranceFee}();
    //     }

    //     uint prize = entranceFee * (additionalEntrants + 1);

    //     vm.recordLogs(); // start recording all emitted events
    //     raffle.performUpkeep(""); // reqId is emitted here
    //     Vm.Log[] memory logs = vm.getRecordedLogs(); // save the recorded logs
    //     bytes32 reqId = logs[1].topics[1]; // It's logs[1], not logs[0] cuz another event is emitted in the VRFCoordinatorV2Mock

    //     uint prevTimestamp = raffle.getLastTimestamp();

    //     // Pretend to be Chainlink VRF to get random number & pick winner
    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
    //         uint(reqId),
    //         address(raffle)
    //     );

    //     assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    //     assert(raffle.getrecentWinner() != address(0));
    //     assert(raffle.getPlayersLength() == 0);
    //     assert(prevTimestamp < raffle.getLastTimestamp());
    //     assert(
    //         raffle.getrecentWinner().balance ==
    //             STARTING_USER_BALANCE + prize - entranceFee
    //     );
    // }
}

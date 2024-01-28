// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/// @title A Raffle contract sample
/// @notice Creating a sample raffle
/// @dev Impl Chainlink VRFv2
contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEth();
    error Raffle_TransferFailed();
    error Raffle_NotOpen();
    error Raffle_UpkeepNotNeeded(
        uint currentBalance,
        uint numPlayers,
        RaffleState raffleState
    );

    enum RaffleState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint16 private constant NUM_WORDS = 1;

    uint private immutable entranceFee;
    uint private immutable interval; // duration of the lottery in secs
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable gasLane;
    uint32 private immutable callbackGasLimit;
    uint private lastTimestamp;

    address payable[] private players;
    address payable private recentWinner;
    RaffleState private raffleState;

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestRaffleWinner(uint indexed winner);

    constructor(
        uint _entranceFee,
        uint _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        entranceFee = _entranceFee;
        interval = _interval;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        gasLane = _gasLane;
        subscriptionId = _subscriptionId;
        lastTimestamp = block.timestamp;
        callbackGasLimit = _callbackGasLimit;
        raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        // In order to enter raffle, we must have enough entrance fee and its state must be open
        if (msg.value < entranceFee) revert Raffle_NotEnoughEth();
        if (raffleState != RaffleState.OPEN) revert Raffle_NotOpen();

        players.push(payable(msg.sender));

        // Why use Event?
        // It makes migration easier and makes FE 'indexing' easier
        emit EnteredRaffle(msg.sender);
    }

    /**
     * When is the winner supposed to be picked?
     *@dev This is the fucntion that the Chainlink Autimation nodes call to
     * see if it's time to perform an upkeep.
     * The following should be true for this func to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka. players)
     * 3. (implicit) The subscription is funced with LINK
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - lastTimestamp) >= interval;
        bool isOpen = raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    /**
     *@notice Pick a winner
     *@dev 1. Get a random number
     *      2. Use that number to pick a player
     *       3. Be automatically called
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded)
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                players.length,
                raffleState
            );

        // check if there is enough time passed
        // block.timestamp: current time
        if ((block.timestamp - lastTimestamp) < interval)
            revert Raffle_NotOpen();

        raffleState = RaffleState.CALCULATING;

        // 1. Request the RNG
        // 2. Get the random number
        uint requestId = vrfCoordinator.requestRandomWords(
            gasLane, // or keyHash
            subscriptionId,
            REQUEST_CONFIRMATION,
            callbackGasLimit,
            NUM_WORDS
        );
        // This is redundant cuz we already have emit request event like this in the VRFCoordinatorV2Mock
        emit RequestRaffleWinner(requestId);
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /* _requestId */,
        uint256[] memory _randomWords
    ) internal override {
        // >> Checks
        // Some logic then require() or if() statement

        // Effects (Our own contracts)
        uint indexOfWinner = _randomWords[0] % players.length;
        address payable winner = players[indexOfWinner];
        recentWinner = winner;

        // >> After picking a winner, we reset the state to open, the players to zero and the last timestamp to current timestamp
        raffleState = RaffleState.OPEN;
        players = new address payable[](0);
        lastTimestamp = block.timestamp;

        // >> Interactions (Other contracts)
        (bool isSuccessful, ) = winner.call{value: address(this).balance}("");
        if (!isSuccessful) revert Raffle_TransferFailed();

        emit PickedWinner(winner);
    }

    function getEntranceFee() external view returns (uint) {
        return entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return raffleState;
    }

    function getPlayer(uint index) external view returns (address) {
        return players[index];
    }

    function getPlayersLength() external view returns (uint) {
        return players.length;
    }

    function getrecentWinner() external view returns (address) {
        return recentWinner;
    }

    function getLastTimestamp() external view returns (uint) {
        return lastTimestamp;
    }
}

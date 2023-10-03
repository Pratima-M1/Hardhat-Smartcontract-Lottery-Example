// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
//import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

/* Errors */
error Raffle__NotEnoughEntryFee();
error Raffle__TransactionFailed();
error Raffle_Is_Not_Open();
error Up_Keep_Not_Needed(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/*  @notice This contract is for creating a sample raffle contract
 */
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    //contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    //ENUM typedeclaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    //state variable
    uint256 private immutable i_entranceFee;
    //we have to pay back the player who wins
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    //lottery variable
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastBlockTimeStamp;
    uint256 private immutable i_interval;
    //events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event Winnerpicked(address indexed winner);

    /*functions */
    // entrance fee should be configurable
    constructor(
        address vrfCoordinatorV2, //contract address
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastBlockTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntryFee();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_Is_Not_Open();
        }
    }

    //pick a random plaer as winner
    // function requestRandomWinner() external {
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Up_Keep_Not_Needed(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gas lane to be paid to request a random number for goerli network
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    //if only user has to call this make it external
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        ){
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        //block.timestamp-last blocktimestamp>interval
        bool timePassed = (block.timestamp - s_lastBlockTimeStamp) > i_interval;
        //to check we have enough players
        bool hasPlayers = s_players.length > 0;
        //if we have enough balance
        bool hasBalance = address(this).balance > 0;
        //if its true its time to end lottery and request a new random number;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
         return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    //fund the winner
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        //once we pickup our winner lottery should be open
        s_raffleState = RaffleState.OPEN;
        //since its open again reset player array
        s_players = new address payable[](0);
        //reset the time stamp
        s_lastBlockTimeStamp = block.timestamp;
        //we have to send money to winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransactionFailed();
        }
        emit Winnerpicked(s_recentWinner);
    }

    /*view or pure  functions*/
    //user must see the entrance fee
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    //since num_words isconstant its stored in bytecode ,pure
    function getnumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastBlockTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
     function getInterval() public view returns (uint256) {
        return i_interval;
    }
}

pragma solidity ^0.4.22;

import "./ownable.sol";

contract CoinToss is Ownable{

    struct Bet{
        uint256 amount; //Wei
        uint128 betNo;
        uint256 blockNo;
        uint16 commitBlockInterval;
        uint16 revealBlockInterval;
        bool result;
        bool isCommitted;
        bool isRevealed;

        Better better1;
        Better better2;
    }

    struct Better{
        address addr_better;
        uint32 key;
        bytes32 randomCommitted;
        bool chosenSide;
        bool isRevealed;
    }

    Bet[] public bets;

    uint128 public betNo = 0;
    uint8  internal feePercentage = 10;
    uint8  internal constant percentageCap = 10;

    mapping(address => Bet) public latest_bet_of_better;
    mapping(address => uint) public pendingWithdraws;
    //mapping(betNo => address) public

    event betFinished(string strFinished, address winner);
    event betCreated(string strCreated);
    event betCommitted(string strCommited);
    event LogRevealHash(string strHash, bytes32);
    event LogBlockNumber(string strBlock, uint256 blockNo);

    modifier beforeBetting(uint betNoOfBet){
        Bet storage bet = bets[betNoOfBet];
        require(bet.isCommitted != true, "Bet is already committed");
        require(block.number <= bet.blockNo + bet.commitBlockInterval, "Commit time is passed");
        require(msg.value == bet.amount, "You have to bet same amount with stake");
        _;
    }
    modifier blankAddress(address _n) {
        require(_n != 0, "Address can't be empty");
        _; }
    modifier minWager(){require(msg.value >= 10 finney); _;}


    event flip(address addr_better_1, address addr_better_2, bool result);

    constructor() public{
    }

    function createAndJoinBet(
                                bool chosenSide,
                                bytes32 _randomCommitted,
                                uint16 _commitBlockInterval,
                                uint16 _commitRevealInterval
                              ) external payable minWager {

        Better memory better = Better(msg.sender, uint32(0), _randomCommitted, chosenSide, false);
        Better memory better2;

        bets.push(Bet(msg.value, betNo, block.number, _commitBlockInterval, _commitRevealInterval, false, false, false, better, better2));

        betNo++;//Bunu asagi al
        //bets[betNo]= Bet(betNo, msg.value, msg.sender, address(0), chosenSide, !chosenSide, false);

        emit betCreated("Bet has been created");
    }

    function joinBet(uint betNoOfBet, bytes32 _randomCommitted) public payable beforeBetting(betNoOfBet) returns(bool){

        bool chosenSide =  bets[betNoOfBet].better1.chosenSide;

        Better memory better2 = Better(msg.sender, uint32(0), _randomCommitted, !chosenSide, false);

        bets[betNoOfBet].better2 = better2;
        bets[betNoOfBet].amount = 2*msg.value;
        bets[betNoOfBet].blockNo += block.number;
        bets[betNoOfBet].isCommitted = true;

        //Calculate random and select winner.
        emit betCommitted("Bet is committed");

        return true;
    }

    modifier beforeReveal(uint128 betNoOfBet){
        require(bets[betNoOfBet].isCommitted == true, "You can't reveal before commitement finished");
        if(bets[betNoOfBet].better1.addr_better != msg.sender){
            require(bets[betNoOfBet].better2.addr_better == msg.sender , "You are not allowed to reveal");
        }
        _;
    }//Bet kapama yaz

    modifier isRevealFinished(uint128 betNoOfBet){
        require(block.number <= bets[betNoOfBet].blockNo + bets[betNoOfBet].revealBlockInterval, "You have missed reveal time!");
        _;
    }

    function revealCommitment(uint128 betNoOfBet, string key, string _address) beforeReveal(betNoOfBet) isRevealFinished(betNoOfBet) external{

        bytes32 hash = keccak256(key, _address);
        Bet storage bet = bets[betNoOfBet];

        emit LogRevealHash("Revealed Hash: ", hash);

        if(msg.sender == bet.better1.addr_better){
            require(hash == bet.better1.randomCommitted,"You have revealed wrong key");
            bet.better1.key = stringToUint(key);
            bet.better1.isRevealed = true;

            if(bet.better2.isRevealed == true) bet.isRevealed = true;
        }else{
            require(hash == bet.better2.randomCommitted,"You have revealed wrong key");
            bet.better2.key = stringToUint(key);
            bet.better2.isRevealed = true;

            if(bet.better1.isRevealed == true) bet.isRevealed = true;
        }

        if(bet.isRevealed == true)
        {
            _calculateToss(betNoOfBet);
        }

    }

    function _calculateToss(uint betNoOfBet) internal{
        Bet storage bet = bets[betNoOfBet];

        address winner;
        uint win_amount;
        uint fee;
        uint32 ultimateKey;

        ultimateKey = bet.better1.key ^ bet.better2.key;
        win_amount = bets[betNoOfBet].amount;

        bet.amount = 0;

        fee = (win_amount*feePercentage)/100;
        win_amount = win_amount - fee;

        if(ultimateKey%2 == 0){
            bet.result = true;//Head
        }else{
            bet.result = false;//Tail;
        }


        if(bet.result == bet.better1.chosenSide){
            winner = bet.better1.addr_better;
            pendingWithdraws[winner] = win_amount;
        }else{
            winner = bet.better2.addr_better;
            pendingWithdraws[winner] = win_amount;
        }

        owner.transfer(fee);
        emit betFinished("Bet finished.", winner);
    }

    function withdraw() external returns(bool result){

       uint amount = pendingWithdraws[msg.sender];

       if(amount > 0){

           pendingWithdraws[msg.sender] = 0;
           msg.sender.transfer(amount);
       }

       return true;
    }

    function setFeePercentage(uint8 _feePercentage) public onlyOwner {
        require(_feePercentage <= percentageCap);
        feePercentage = _feePercentage;
    }

    function printBlockNumber() external{
        emit LogBlockNumber("Block Number is: ", block.number);
    }

    function stringToUint(string s) internal constant returns (uint32) {
        bytes memory b = bytes(s);
        uint32 result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (b[i] >= 48 && b[i] <= 57) {
                result = result * 10 + (uint32(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }


}

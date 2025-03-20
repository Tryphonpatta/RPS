
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";
contract RPS {
    TimeUnit public timeUnit;
    CommitReveal public commitReveal;

    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numReveal = 0;
    mapping (address => uint) public player_choice; // 0 - Scissors, 1 - Paper , 2 - Rock, 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    address[] public players;
	address[] public allowPlayers = [0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB];

    uint public numInput = 0;
    uint public timeLimit = 30;
    constructor(address _timeUnit, address _commitReveal){
        timeUnit = TimeUnit(_timeUnit);
        commitReveal = CommitReveal(_commitReveal);
    }
    function addPlayer() public payable {
        require(numPlayer < 2);
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        require(msg.value == 1 ether);
		if(allowPlayers[0] != msg.sender && allowPlayers[1] != msg.sender && allowPlayers[2] != msg.sender && allowPlayers[3] != msg.sender){
			require(false, "You are not allowed to play this game");
		}
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
        //set time
        if(numPlayer == 1){
            timeUnit.setStartTime();
        }
    }

    function commit(bytes32 hash) public  {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        // require(choice == 0 || choice == 1 || choice == 2 || choice == 3 || choice == 4);
        // bytes32 hashInput = commitReveal.getHash(bytes32(choice));
        commitReveal.commit(hash,msg.sender);
        // player_choice[msg.sender] = choice;
        if (player_not_played[msg.sender]) {
            numInput ++;
            player_not_played[msg.sender] = false;
        }
        // if (numInput == 2) {
        //     _checkWinnerAndPay();
        // }
    }

    function reveal(bytes32 hash) public {
        require(numPlayer == 2);
        require(numInput == 2);
        commitReveal.reveal(hash,msg.sender);
        uint choice = uint(uint8(hash[31]));
        require(choice >= 0 && choice <= 4, "choice is not valid.");
        player_choice[msg.sender] = choice;
        numReveal ++;
        if(numReveal == 2){
            _checkWinnerAndPay();
        }
        
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        if ((p0Choice + 1) % 3 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            // to pay player[1]
            account0.transfer(reward);
        }
        else if ((p1Choice + 1) % 3 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            // to pay player[0]
            account1.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        reset();
    }

    function cancelGame() public {
        if(numPlayer == 1 && timeUnit.elapsedSeconds() >= timeLimit){
            address payable  account = payable(players[0]);
            account.transfer(reward);
        }
        else if (numPlayer == 2 && numReveal == 0 && timeUnit.elapsedSeconds() >= timeLimit){
            address payable account1 = payable(players[0]);
            address payable account2 = payable(players[1]);
            account1.transfer(reward/2);
            account2.transfer(reward/2);
        }
        else if (numPlayer == 2 && numReveal <= 1 && timeUnit.elapsedSeconds() >= timeLimit) {
            address payable account = payable(msg.sender);
            address target;
            if(msg.sender == players[0])target = players[1];
            else target = players[0];
            (,,bool revealed) = commitReveal.commits(target);
            if(!revealed) {
                account.transfer(reward);
            }
        }
        else {
            require(false,"cannot refund");
        }
        reset();
    }

    function reset() private {
        reward = 0;
        for (uint i = 0; i < players.length; i++) {
            delete player_choice[players[i]];
            delete player_not_played[players[i]];
        }
        delete players;
        numPlayer = 0;
        numInput = 0;
        numReveal = 0;

    }
}
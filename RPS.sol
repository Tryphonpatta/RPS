// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";
import "./IERC20.sol";

contract RPS {
    TimeUnit public timeUnit;
    CommitReveal public commitReveal;
    IERC20 public token;

    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numReveal = 0;
    uint public constant REQUIRED_AMOUNT = 0.000001 ether;
    
    mapping (address => uint) public player_choice; // 0 - Scissors, 1 - Paper, 2 - Rock, 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    address[] public players;

    uint public numInput = 0;
    uint public timeLimit = 30;
    bool public fundsCaptured = false;
    
    constructor(address _timeUnit, address _commitReveal, address _token) {
        timeUnit = TimeUnit(_timeUnit);
        commitReveal = CommitReveal(_commitReveal);
        token = IERC20(_token);
    }
    
    function addPlayer() public {
        require(numPlayer < 2, "Game already has 2 players");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "You are already registered as a player");
        }
        
        // Check if player has approved the required amount
        require(
            token.allowance(msg.sender, address(this)) >= REQUIRED_AMOUNT,
            "Insufficient token allowance"
        );
        
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
        
        if(numPlayer == 1) {
            timeUnit.setStartTime();
        }
    }

    function commit(bytes32 hash) public {
        require(numPlayer == 2, "Need exactly 2 players");
        require(player_not_played[msg.sender], "You already made your choice");
        
        // Check if player still has approved the required amount
        require(
            token.allowance(msg.sender, address(this)) >= REQUIRED_AMOUNT,
            "Insufficient token allowance"
        );
        
        commitReveal.commit(hash, msg.sender);
        
        if (player_not_played[msg.sender]) {
            numInput++;
            player_not_played[msg.sender] = false;
        }
        
        // If both players have committed, transfer tokens immediately
        if (numInput == 2 && !fundsCaptured) {
            // Check both players still have sufficient allowance
            require(
                token.allowance(players[0], address(this)) >= REQUIRED_AMOUNT &&
                token.allowance(players[1], address(this)) >= REQUIRED_AMOUNT,
                "Insufficient token allowance"
            );
            
            // Transfer tokens from both players to contract
            _safeTransferFrom(token, players[0], address(this), REQUIRED_AMOUNT);
            _safeTransferFrom(token, players[1], address(this), REQUIRED_AMOUNT);
            reward = REQUIRED_AMOUNT * 2;
            fundsCaptured = true;
        }
    }

    function reveal(bytes32 hash) public {
        require(numPlayer == 2, "Need exactly 2 players");
        require(numInput == 2, "Both players must commit first");
        require(fundsCaptured, "Funds not yet transferred to contract");
        
        commitReveal.reveal(hash, msg.sender);
        uint choice = uint(uint8(hash[31]));
        require(choice >= 0 && choice <= 4, "Choice is not valid");
        
        player_choice[msg.sender] = choice;
        numReveal++;
        
        if(numReveal == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        
        if ((p0Choice + 1) % 3 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            // Player 0 wins
            bool sent = token.transfer(players[0], reward);
            require(sent, "Token transfer failed");
        }
        else if ((p1Choice + 1) % 3 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            // Player 1 wins
            bool sent = token.transfer(players[1], reward);
            require(sent, "Token transfer failed");
        }
        else {
            // Draw - split reward
            bool sent1 = token.transfer(players[0], reward / 2);
            bool sent2 = token.transfer(players[1], reward / 2);
            require(sent1 && sent2, "Token transfer failed");
        }
        reset();
    }

    function claimTimeoutWin() public {
        require(numPlayer == 2 && fundsCaptured, "Game not in correct state");
        require(timeUnit.elapsedSeconds() >= timeLimit, "Time limit not reached");
        require(numReveal < 2, "Both players already revealed");
        
        if (numReveal == 0) {
            // Anyone can claim if neither player revealed
            bool sent = token.transfer(msg.sender, reward);
            require(sent, "Token transfer failed");
        } else {
            // Only the player who revealed can claim if one player revealed
            (,,bool revealed1) = commitReveal.commits(players[0]);
            (,,bool revealed2) = commitReveal.commits(players[1]);
            
            if (revealed1 && !revealed2 && msg.sender == players[0]) {
                bool sent = token.transfer(players[0], reward);
                require(sent, "Token transfer failed");
            } else if (!revealed1 && revealed2 && msg.sender == players[1]) {
                bool sent = token.transfer(players[1], reward);
                require(sent, "Token transfer failed");
            } else {
                revert("You cannot claim the reward");
            }
        }
        reset();
    }

    function reset() private {
        reward = 0;
        fundsCaptured = false;
        for (uint i = 0; i < players.length; i++) {
            delete player_choice[players[i]];
            delete player_not_played[players[i]];
        }
        delete players;
        numPlayer = 0;
        numInput = 0;
        numReveal = 0;
    }

    function _safeTransferFrom(
        IERC20 ierc20Token,
        address sender,
        address recipient,
        uint256 amount
    ) private {
        bool sent = ierc20Token.transferFrom(sender, recipient, amount);
        require(sent, "Token transfer failed");
    }
}
pragma solidity ^0.5.7;

contract RockPaperScissor {
    
    // Address of the contract creator
    address private owner;
    
    // The addresses of the players
    address private player1;
    address private player2;
    
    // Amount one has to deposit to play
    int constant public depositAmount = int(5 finney); //1 ether = 10^3 finney
    
    // Mapping to keep commitments and moves of the players
    mapping(address => bytes32) private comms;
    mapping(address => string) private moves;
    
    // All possible states of RPS.
    // Returns 1 if player 1 wins, 2 if player 2 wins and 0 if they draw
    mapping (string => mapping(string => int)) private gameState;
    
    // Contract keeps track of balances of player
    mapping(address => int) private balances;
    
    // Attributess to keep track of elapsed time to prevent DoS attacks
    uint public gameStartTime;
    uint constant public maxGameTime = 120 seconds;
    
    // to handle game logic and penalize bad behaviour, i.e, committing but not opening in time
    bool private firstCommOpened;
    bool private penalize;
    
    
    constructor() public {
        // r, p, s denote rock, paper and scissor, respectively
       gameState["r"]["r"] = 0;
       gameState["r"]["s"] = 1;
       gameState["r"]["p"] = 2;
       gameState["s"]["s"] = 0;
       gameState["s"]["p"] = 1;
       gameState["s"]["r"] = 2;
       gameState["p"]["p"] = 0;
       gameState["p"]["r"] = 1;
       gameState["p"]["s"] = 2;
       firstCommOpened = false;
       penalize = false;
       owner = msg.sender;
    }
    
    function getTime() public view returns(uint) {
        return block.timestamp;
        
    }
    
    function commitMove(bytes32 comm) payable public {
        require(player1 == address(0) || player2 == address(0), "A game is in progress. Please wait for it to finish.");
        require(int(msg.value) == depositAmount, "You need to deposit 5 finney to play.");
        
        // First caller is designated as player 1
        if (player1 == address(0)) {
            player1 = msg.sender;
        }
        else if (player2 == address(0)){
            player2 = msg.sender;
            gameStartTime = block.timestamp;
            
        }
        comms[msg.sender] = comm;
        balances[msg.sender] += depositAmount;
    }
    
    function openMove(string memory move, string memory rand) public returns(int) {
        require(msg.sender == player1 || msg.sender == player2, "A game is in progress. Please wait for it to finish.");
        require(comms[player1].length != 0 && comms[player2].length != 0, "Both parties must commit first.");
        
        if (msg.sender == player1) {
            // if a player makes an invalid opening, end the current game by rewarding the other player
            if (!isOpeningValid(move, rand, player1)) {
                //assign a winning state to player 2
                moves[player1] = 'r';
                moves[player2] = 'p';
                
            }
            // player1 opens his commitment first        
            else if (!firstCommOpened) {
                moves[player1] = move;
                firstCommOpened = true;
            }
            // player2 has opened before. 
            else {
                moves[player1] = move;
                endGame();
            }
        }
        else if (msg.sender == player2) {
            if (!isOpeningValid(move, rand, player2)) {
                //assign a winning state to player 1
                moves[player1] = 'p';
                moves[player2] = 'r';
                
            }
            // player2 opens his commitment first        
            else if (!firstCommOpened) {
                moves[player2] = move;
                firstCommOpened = true;
            }
            // player1 has opened before. 
            else {
                moves[player2] = move;
                endGame();
            }
        }
    }
    
    // end the current running game by distributing the rewards and restart a new game
    function endGame() private returns(int) {
       int result = gameState[moves[player1]][moves[player2]];
       // player1 wins
       if (result == 1){
           balances[player1] += depositAmount;
           balances[player2] -= depositAmount;
       }
       // player2 wins
       else if (result == 2) {
           balances[player1] -= depositAmount;
           balances[player2] += depositAmount;
       }
       // transfer some deposit amount to contract creator to penalize
       else if (penalize) {
           balances[owner] += 2 finney;
           balances[player1] -= 1 finney;
           balances[player2] -= 1 finney;
       }
       
       resetGame();
    }
    
    // reset the game by setting player addresses to 0 which makes commitMove callable again
    function resetGame() private {
        delete comms[player1];
        delete comms[player2];
        delete moves[player1];
        delete moves[player2];
        player1 = address(0);
        player2 = address(0);
        gameStartTime = 0;
        firstCommOpened = false;
        penalize = false;
    }
    
    // A function to prevent DOS attacks, i.e., someone commits but never opens. 
    // Anyone is able to start a new game if the ongoing game takes more than 120 seconds
    function requestToRestart() public {
        require(gameStartTime != 0, "There's no game in progress. You can start playing by commitming to a move.");
        require((now - gameStartTime) > maxGameTime, "To restart a game, 120 seconds has to be elapsed since the game began.");
        
        // case 1: player1 opened his commitment and player2 didn't. reward player1.
        if (!isEqualString(moves[player1], "") && isEqualString(moves[player2], "")) {
            //assign a winning state to player 1
            moves[player1] = 'p';
            moves[player2] = 'r';
        }
        // case 2: player2 opened his commitment and player1 didn't. reward player2.
        else if (isEqualString(moves[player1], "") && !isEqualString(moves[player2], "")) {
            //assign a winning state to player 2
            moves[player1] = 'r';
            moves[player2] = 'p';
        }
        //case 3: both didn't open. penalize the players.
        else if (isEqualString(moves[player1], "") && isEqualString(moves[player2], "")) {
            penalize = true;
        }
        
        endGame();
    }
    
    // show user his net balance resulting from playing the game
    function getBalance() public view returns(int256) {
        return balances[msg.sender];
    }
    
    // a player can claim the amount in his balance by calling this method
    function claimBalance() public payable {
        require(msg.sender != player1 && msg.sender != player2, "You can't checkout while playing a game.");
        require(balances[msg.sender] > 0, "You need to have a positive balance.");
        
        //send the whole amount in balance to caller and set the balance to 0 afterwards
        msg.sender.send(uint(balances[msg.sender]));
        delete balances[msg.sender];
    }
    
    // Determine whether or not a move is valid. Valid moves are (r)ock, (p)aper and (s)scissor.
    function isValidMove(string memory move) private view returns(bool) {
        return isEqualString(move, 'r') || isEqualString(move, 'p') || isEqualString(move, 's');
    }
    
    // Computes commitment of message m with randomness r as keccak256(h||r) where || is string concatanation
    // this is public for testing purposes, no player should compute the commitment by calling this
    function computeCommitment(string memory m, string memory r) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(append(m, r)));
    }
    
     // Determine whether or not player's opening is valid
    function isOpeningValid(string memory m, string memory r, address player) private view returns(bool) {
        return isValidMove(m) && (comms[player] == computeCommitment(m, r));
    }
    
    // Auxiliary method to do string comparison as solidity lacks a native one. keccak256 is a hash function.
    function isEqualString (string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))) );
    }
    
    // Auxiliary method to concatanate strings a and b
    function append(string memory a, string memory b) private pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}

pragma solidity ^0.5.7;

contract RockPaperScissor {
    
    // The addresses of the players
    address public player1;
    address public player2;

    // Mapping to keep commitments and moves of the players
    mapping(address => bytes32) public comms;
    mapping(address => string) public moves;
    
    // All possible states of RPS.
    // Returns 1 if player 1 wins, 2 if player 2 wins and 0 if draw
    mapping (string => mapping(string => int)) public gameState;
    
    // Contract keeps track of net profits of player
    mapping(address => int) private balances;
    
    // Timing attributes related with opening phase
    bool public firstCommOpened;

    constructor() public {
        bool firstCommOpened = false;
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
    }
    
    
    
    function commitMove(bytes32 comm) payable public {
        require(player1 == address(0) || player2 == address(0), "A game is in progress. Please wait for it to finish.");
        // First caller is designated as player 1
        if (player1 == address(0)) {
            player1 = msg.sender;
        }
        else if (player2 == address(0)){
            player2 = msg.sender;
        }
        comms[msg.sender] = comm;
        balances[msg.sender] -= 2; //TODO: replace this with ether, add ether check to top
    }
    
    
    function openMove(string memory move, string memory rand) public returns(int){
        require(msg.sender == player1 || msg.sender == player2, "A game is in progress. Please wait for it to finish.");
        require(comms[player1].length != 0 && comms[player2].length != 0, "Both parties must commit first.");
        
        if (msg.sender == player1) {
            // if a player makes an invalid opening, end the current game by rewarding the other player
            if (!isOpeningValid(move, rand, player1)) {
                //assigning a winning state to player 2
            }
            // player1 opens his commitment first        
            else if (!firstCommOpened) {
                moves[player1] = move;
                firstCommOpened = true;
            }
            // player2 has opened before. TODO: Do time check here
            else {
                moves[player1] = move;
                endGame();
            }
        }
        else if (msg.sender == player2) {
            // if a player makes an invalid opening, end the current game by rewarding the other player
            if (!isOpeningValid(move, rand, player2)) {
                
            }
            // player2 opens his commitment first        
            else if (!firstCommOpened) {
                moves[player2] = move;
                firstCommOpened = true;
            }
            // player1 has opened before. TODO: Do time check here
            else {
                moves[player2] = move;
                endGame();
            }
        }
    }
    
    
    // end the current running game by distributing rewards and restart a new game
    function endGame() private returns(int) {
       int result = gameState[moves[player1]][moves[player2]];
       // player1 wins
       if (result == 1){
           balances[player1] += 4;
       }
       // player2 wins
       else if (result == 2) {
           balances[player2] += 4;
       }
       // draw
       else {
           balances[player1] += 2;
           balances[player2] += 2;
       }
       resetGame();
    }
    
    
    // reset the game by setting player addresses to 0 which makes commitMove callable again
    function resetGame() private {
        delete comms[player1];
        delete comms[player2];
        player1 = address(0);
        player2 = address(0);
        firstCommOpened = false;
        
    }
    
    // show user his balance resulting from playing the game
    function showBalance() public view returns(int256) {
        return balances[msg.sender];
    }
    
    // Determine whether or not player's opening is valid
    function isOpeningValid(string memory m, string memory r, address player) public view returns(bool) {
        return isValidMove(m) && (comms[player] == computeCommitment(m, r));
    }
     
    
    // Determine whether or not a move is valid. Valid moves are r, p and s.
    function isValidMove(string memory move) public view returns(bool) {
        return compareStrings(move, 'r') || compareStrings(move, 'p') || compareStrings(move, 's');
    }
    
    
    // Computes commitment of message m with randomness r 
    // as keccak256(h||r) where || is string concatanation
    function computeCommitment(string memory m, string memory r) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(append(m, r)));
    }
    
    
    // Auxiliary method to do string comparison as solidity lacks a native one. keccak256 is a hash function.
    function compareStrings (string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))) );
    }
    
    // Auxiliary method to concatanate strings a and b
    function append(string memory a, string memory b) private pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}


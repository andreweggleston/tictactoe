// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract TicTacToe {
    
    struct Game {
        address player1;
        address player2;
        uint256 bet_amount;

        bool turn_is_player2;

        uint16 board1;
        uint16 board2;
        
        bool ready; //these two bools could become one enum State {Challenged, InProgress, Expired, Complete}
        bool canceled; 

        uint256 time_expired;
    }

    mapping(uint256 => Game) games;
    uint256 num_games; //used as a monotonically incrementing ID, used by functions to index into the above mapping

    /*
    * The board state will be represented by 2 sets of 9 bit numbers: one for each player
    * 
    * bit number and position: 
    *
    *               ┌> 84
    *  ┌───┬───┬───┐
    *  │ 0 │ 1 │ 2 │ -> 7
    *  ├───┼───┼───┤
    *  │ 3 │ 4 │ 5 │ -> 56
    *  ├───┼───┼───┤
    *  │ 6 │ 7 │ 8 │ -> 448
    *  └───┴───┴───┘
    *    │   │   │  └> 273 
    *    v   │   │
    *   73   v   │
    *        146 v
    *            292
    * Therefore, winning states can be described as numbers: 
    * e.g. the top row is (2^0)+(2^1)+(2^2) = 1+2+4 = 7
    *      middle row is  8+16+32 = 56
    *      and so on
    * 
    * Use bitwise logic to check squares. To check if the "Nth" square of the board is empty
    * check if (board & (1<<N)) == 0.
    * If the value is > 0 than it it is filled
    */


    constructor() {
        num_games = 0;
    }

    modifier game_exists(uint256 game_id) {
        require(games[game_id].player1 > address(0), "Game for that id doesn't exist"); //checking that at least one field is initialized
        _;
    }

    modifier only_current_player(Game storage game) {
        if(game.turn_is_player2) {
            require(msg.sender == game.player2, "Message sender must be player 2");
        } else {
            require(msg.sender == game.player1, "Message sender must be player 1");
        }
        _;
    }

    modifier game_running(Game storage game) {
        require(game.ready, "Game is not running");
        _;
    }

    function game_is_ready(uint256 game_id) public view game_exists(game_id) returns(bool) {
        return games[game_id].ready;
    }

    function get_board1(uint256 game_id) public view game_exists(game_id) returns(uint16) {
        return games[game_id].board1;
    }
    
    function get_board2(uint256 game_id) public view game_exists(game_id) returns(uint16) {
        return games[game_id].board2;
    }

    /// @param opponent The address to challenge to a game
    /// @param waittime How long until the challenge is void and the amount paid by the 'challenger' is unlocked
    /// This function should be called when a user wants to start a new game of Tic Tac Toe.
    /// The msg.value of the call is used as the amount 'bet' on the game, and the 'challenged' account is expected to pay the same
    ///     when they accept the challenge.
    /// @return game_id of the created game; the players must remember the game_id as they play.
    function create_game(address opponent, uint256 waittime) payable public returns(uint256) {
        num_games++;
        games[num_games] = Game({
            player1: msg.sender,
            player2: opponent,
            bet_amount: msg.value,
            turn_is_player2: true,
            time_expired: block.timestamp + waittime,
            board1: 0,
            board2: 0,
            ready: false,
            canceled: false
        });

        return num_games;
    }

    /// @param game_id the game id of the Tic Tac Toe game to start
    /// This function is used by the 'challenged' user to start a game.
    /// The challenged user will be refunded any amount paid
    function accept_challenge(uint256 game_id) payable public game_exists(game_id) {
        Game storage game = games[game_id];
        require(msg.sender == game.player2, "Unchallenged user cannot respond to a challenge");
        require(!(game.canceled), "The game has been canceled");

        require(msg.value >= game.bet_amount, "Challenge acception must be paid at least the amount bet by the challenger");
        if(msg.value > game.bet_amount){
            //refund difference
            (bool sent, /*bytes memory data*/) = msg.sender.call{value: msg.value - game.bet_amount}("");
            require(sent, "failed to refund extra eth");
        }
        game.ready = true;
    }


    uint16 constant FULL_BOARD_STATE = 511;

    /// @param game_id the game id of the Tic Tac Toe game to play on
    /// @param location the grid location (0-8) to play a mark on
    /// This function is called by players of the game to place marks on the board
    function play_a_turn(uint256 game_id, uint8 location) 
    public 
    game_exists(game_id) 
    only_current_player(games[game_id]) 
    game_running(games[game_id]) 
    {
        Game storage game = games[game_id];
        require(location < 9, "location out of bounds"); //dont use <= because EVM doesn't have LTE opcode
        require((game.board1 | game.board2) & (1<<location) == 0, "location already filled");
        if(game.turn_is_player2) {
            player2_turn(game_id, location);
        } else {
            player1_turn(game_id, location);
        }
        if((game.board1 | game.board2 == FULL_BOARD_STATE)) {
            payout_tie(game_id, payable(game.player1), payable(game.player2));
        }
        game.turn_is_player2 = !game.turn_is_player2;
    }

    /// @param game_id the game id of the Tic Tac Toe game to cancel
    /// This function requires that accept_challenge has not been called successfully for this game_id.
    /// It would be used by the challenger (the address who called create_game) if the challenged (opponent)
    ///     address never responded to the challenge.
    function cancel_challenge(uint256 game_id) public game_exists(game_id) {
        require(msg.sender == games[game_id].player1, "only the challenger can refund"); 
        require(block.timestamp > games[game_id].time_expired, "refund can only be processed after the game has expired");
        require(games[game_id].ready == false, "the game has already been started"); 
        (bool sent, /*bytes memory data*/) = payable(games[game_id].player1).call{value: games[game_id].bet_amount}("");
        require(sent, "failed to send eth back to deployer");
        games[game_id].canceled = true;
    }

//====================== Private Functions 
/*
  I thought a lot about how to do this. The problem with this is my 'board state' 
  is just a 16 bit number (and only the lowest 9 bits are used).
  There is one of these 16 bit 'state' numbers for each player.

  The player move function (play_a_turn) has to modify the correct 'state' (board1 or board2).
  This means I'm going to do the same steps for each board
    - Do the move
    - check the board state against each of the winning arrangements
    - if there is a win, pay out the player that just did the move, and end the game
  
  This means that based on whose turn it is, I am checking a different board 
  (and potentially paying out to a different address).
  I need the if statement checking on `turn_is_player2`.
  
  To simplify the play_a_turn function, I split out the player1 turn and player2 turn functions
  into their own functions, even though the logic they are doing is almost identical.
*/


    function player1_turn(uint256 game_id, uint8 location) 
    private 
    game_exists(game_id)
    game_running(games[game_id])
    {
        Game storage game = games[game_id]; //this is like a c pointer
        game.board1 |= uint16(1<<location);
        if(board_has_winning_arrangement(game.board1)) {
            game.ready = false;
            payout(game_id, payable(game.player1));
        }
    }

    function player2_turn(uint256 game_id, uint8 location)
    private 
    game_exists(game_id)
    game_running(games[game_id])
    {   
        Game storage game = games[game_id];
        game.board2 |= uint16(1<<location);
        if(board_has_winning_arrangement(game.board2)) {
            game.ready = false;
            payout(game_id, payable(game.player2));
        }
    }

    //uint16[] WINNING_STATES = [7, 56, 448, 73, 146, 292, 273, 84]; 
    /// @param board a 16 bit int representing a board. only the bottom 9 bits are used
    function board_has_winning_arrangement(uint16 board) private pure returns(bool) {
        return (
            (7 == 7 & board)
            ||
            (56 == 56 & board)
            ||
            (448 == 448 & board)
            ||
            (73 == 73 & board)
            ||
            (146 == 146 & board)
            ||
            (292 == 292 & board)
            ||
            (273 == 273 & board)
            ||
            (84 == 84 & board)
        );
    }

    /// @param game_id to pay out of
    /// @param winner address of the winner who will be debited the initial bet_amount of the game doubled.
    function payout(uint256 game_id, address payable winner) 
    private 
    game_exists(game_id)
    {   
        (bool sent, /*bytes memory data*/) = winner.call{value: games[game_id].bet_amount * 2}("");
        require(sent, "failed to send eth to withdrawer");
    }

    function payout_tie(uint256 game_id, address payable p1, address payable p2)
    private
    game_exists(game_id)
    {
        (bool sent1, /*bytes memory data*/) = p1.call{value: games[game_id].bet_amount}("");
        (bool sent2, /*bytes memory data*/) = p2.call{value: games[game_id].bet_amount}("");
        require(sent1 && sent2, "failed to payout tie");
    }
}

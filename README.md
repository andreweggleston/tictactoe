## TicTacToe.sol

**An Ethereum smart contract which manages Tic Tac Toe games. Users challenge one another to games for an amount of eth, and are awarded for winning.**

A game is created when a wallet (the `challenger`) calls the `create_game` function a `value` of eth they would like to bet, as well as an address of their `opponent` and an amount of time in seconds until the game challenge is expired. The `challenger` is returned an integer `game_id` of the created game. The `challenger` will get the second turn in the game.
The opponent address (the `challenged`) can call the `accept_challenge` function with the `game_id` of the game created by their `challenger`, passing a `value` of eth >= the value sent by the `challenger`. The `challenged` will be refunded any amount above the value sent by the `challenger`. If this function succeeds, the game will be ready to be played.
If the `challenged` fails to call the `accept_challenge` function before the game is expired, the `challenger` will be able to call the `cancel_challenge` function to be refunded the eth they deposited.
Once a game is created by a `challenger` and then accepted by the `challenged`, each player alternates calling the `play_a_turn` function, starting with the `challenged`. The `play_a_turn` function takes a `game_id` of the game to take a turn on, and a `location` integer 0-8 which corresponds to a board cell (see TicTacToe.sol).
When a game is won, the winner recieves the total amount of eth deposited for that game (double the amount they sent to create/accept the game -- their original amount as well as the amount sent by their opponent). If a game is tied, both players are refunded they amount they sent.

See TicTacToe.sol for implementation, it is heavily commented the specifics.

Some issues:
* It seems that there is a difference in gas cost for the `challenger` vs the `challenged` calling `play_a_function` (3123 gas for the challenged but only 3095 gas for the challenger). This might be due to player1's turn and player2's turns using different functions behind the hood, or something to do with how `play_a_turn` checks which players turn it is.
* Testing could be a lot more exhaustive.
* The implementation of the player boards could probably be changed to use one uint32 instead of two uint16s -- might solve the gas issue.
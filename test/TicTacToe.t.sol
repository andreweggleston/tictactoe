// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {TicTacToe} from "../src/TicTacToe.sol";

contract TicTacToeTest is Test {
    TicTacToe public tictactoe;
    address deployer = address(0x1234);
    address challenged = address(0x2345);
    mapping(address=>mapping(address=>uint256)) game_id_mappings;

    function setUp() public {
        vm.prank(deployer);
        tictactoe = new TicTacToe();
        vm.deal(deployer, 10 ether);
        vm.deal(challenged, 10 ether);

        vm.prank(deployer);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("create_game(address,uint256)", challenged, 86400));
        require(callSuccess);
        game_id_mappings[deployer][challenged] = uint256(bytes32(data));
    }

    function test_accept_challenge() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);
    }

    function test_play_some_moves() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 0);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 2);
    }

    function test_play_until_tie() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);
        emit log_named_uint("challenged balance", address(challenged).balance);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 0);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 6);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 2);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 1);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 7);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 3);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 5);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 8);
        require(address(challenged).balance == 10 ether, "challenged balance didn't increase");
        require(address(deployer).balance == 10 ether, "challenger balance didn't increase");
    }

    function test_play_move_on_mark_already_played() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        vm.expectRevert();
        tictactoe.play_a_turn(game_id, 4); //should fail
    }

    function test_play_move_on_mark_already_played_2() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 0); 
        vm.prank(challenged);
        vm.expectRevert();
        tictactoe.play_a_turn(game_id, 4); //should fail
    }

    function test_player_cant_play_twice() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(challenged);
        vm.expectRevert();
        tictactoe.play_a_turn(game_id, 0); //should fail
    }

    function test_play_until_p1_wins() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 0);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 2);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 1);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 6);
        require(address(challenged).balance > 10 ether);
        require(address(deployer).balance < 10 ether);
    }
    
    function test_play_until_p2_wins() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 0);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 2);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 6);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 1);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 3);
        require(address(deployer).balance > 10 ether);
        require(address(challenged).balance < 10 ether);
    }

    function test_cant_play_a_turn_after_winner() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 0);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 2);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 6);
        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 1);
        vm.prank(deployer);
        tictactoe.play_a_turn(game_id, 3); //should be a winner after this

        require(!tictactoe.game_is_ready(game_id), "game is still in ready state after win");
        vm.prank(challenged);
        vm.expectRevert();
        tictactoe.play_a_turn(game_id, 7);
    }

    function test_cant_play_a_turn_with_invalid_location() public {
        uint256 game_id = game_id_mappings[deployer][challenged];
        vm.prank(challenged);
        (bool callSuccess, bytes memory data) = address(tictactoe).call{value: 1 ether}(abi.encodeWithSignature("accept_challenge(uint256)", game_id));
        require(callSuccess);

        vm.prank(challenged);
        tictactoe.play_a_turn(game_id, 4);
        vm.prank(deployer);
        vm.expectRevert();
        tictactoe.play_a_turn(game_id, 9);
    }
}

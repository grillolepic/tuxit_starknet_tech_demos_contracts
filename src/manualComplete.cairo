%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_nn_le, assert_not_equal, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.alloc import alloc
from lib.TuxitPacked import TuxitPacked
from src.tuxit import PackedAction

struct Player {
    x: felt,
    y: felt,
    orientation: felt,
    hit: felt,
    apples: felt,
    oranges: felt,
    pears: felt,
}

struct Shot {
    id: felt,
    x: felt,
    y: felt,
    type: felt,
    direction: felt,
}

struct Tile {
    x: felt,
    y: felt,
}

//Fixed State
@view
func load_and_verify_fixed_state{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    fixed_data_len: felt,
    fixed_data: felt*,
    public_keys_len: felt,
    public_keys: felt*,
    signatures_len: felt,
    signatures: (felt, felt)*,
) -> (
    grid_width: felt,
    grid_area: felt,
    map_len: felt,
    map: felt*,
    total_players: felt,
    player_indices_len: felt,
    player_indices: felt*
) {
    alloc_locals;

    //First, hash the data and verify the provided signatures
    let hashed_data = TuxitPacked.hash_array(fixed_data_len, fixed_data);
    TuxitPacked.verify_signatures(hashed_data, public_keys_len, public_keys, signatures_len, signatures);

    //Then, load the data from the array. This changes from game to game
    let (grid_width, remaining_data, read_pointer) = TuxitPacked.read_single(fixed_data_len, fixed_data, 8, fixed_data[0], TuxitPacked.ReadPointer(0,0));
    let (grid_area, remaining_data, read_pointer) = TuxitPacked.read_single(fixed_data_len, fixed_data, 16, remaining_data, read_pointer);

    let (map: felt*) = alloc();
    let (remaining_data, read_pointer) = TuxitPacked.read_array(fixed_data_len, fixed_data, 3, remaining_data, read_pointer, grid_area, 0, map);

    let (total_players, remaining_data, read_pointer) = TuxitPacked.read_single(fixed_data_len, fixed_data, 3, remaining_data, read_pointer);

    let (player_indices: felt*) = alloc();
    let (remaining_data, read_pointer) = TuxitPacked.read_array(fixed_data_len, fixed_data, 3, remaining_data, read_pointer, total_players, 0, player_indices);

    //Lastly, verify the amount of signatures is equal to the amount of players as encoded on the game data
    with_attr error_message("Wrong amount of player signatures") {
        assert total_players = public_keys_len;
    }

    return (grid_width, grid_area, grid_area, map, total_players, total_players, player_indices);
}


//Checkpoints
@view
func load_and_verify_checkpoint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    checkpoint_data_len: felt,
    checkpoint_data: felt*,
    public_keys_len: felt,
    public_keys: felt*,
    signatures_len: felt,
    signatures: (felt, felt)*,
) -> (
    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt
) {
    alloc_locals;

    //First, hash the data and verify the provided signatures
    let hashed_data = TuxitPacked.hash_array(checkpoint_data_len, checkpoint_data);
    TuxitPacked.verify_signatures(hashed_data, public_keys_len, public_keys, signatures_len, signatures);

    //Then, load the data from the array. This changes from game to game
    let (turn, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, checkpoint_data[0], TuxitPacked.ReadPointer(0,0));
    let (last_shot, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, remaining_data, read_pointer);
    let (finished, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 1, remaining_data, read_pointer);
    let (winner, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 3, remaining_data, read_pointer);

    with_attr error_message("Wrong amopunt of player's data") {
        assert public_keys_len = (checkpoint_data_len - 2);
    }

    let (players: Player*) = alloc();
    load_players_from_checkpoint(checkpoint_data_len, checkpoint_data, 0, public_keys_len, players);

    let shots_len = checkpoint_data_len - public_keys_len - 2;
    let (shots: Shot*) = alloc();
    load_shots_from_checkpoint(checkpoint_data_len, checkpoint_data, public_keys_len, 0, shots_len, shots);

    return (turn, last_shot, finished, winner, public_keys_len, players, shots_len, shots, checkpoint_data[checkpoint_data_len-1]);
}

func load_players_from_checkpoint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    checkpoint_data_len: felt,
    checkpoint_data: felt*,
    index: felt,
    players_len: felt,
    players: Player*,
) {
    alloc_locals;

    if (index == players_len) {
        return();
    }

    let (local x, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, checkpoint_data[index+1], TuxitPacked.ReadPointer(index+1,0));
    let (local y, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, remaining_data, read_pointer);
    let (local orientation, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 2, remaining_data, read_pointer);
    let (local shot, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 1, remaining_data, read_pointer);
    let (local apples, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 16, remaining_data, read_pointer);
    let (local oranges, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 16, remaining_data, read_pointer);
    let (local pears, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 16, remaining_data, read_pointer);
    
    assert players[index] = Player(x, y, orientation, shot, apples, oranges, pears);

    return load_players_from_checkpoint(checkpoint_data_len, checkpoint_data, index + 1, players_len, players);
}

func load_shots_from_checkpoint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    checkpoint_data_len: felt,
    checkpoint_data: felt*,
    players_len: felt,
    index: felt,
    shots_len: felt,
    shots: Shot*,
) {
    alloc_locals;

    if (index == shots_len) {
        return();
    }

    let (local id, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, checkpoint_data[index + 1 + players_len], TuxitPacked.ReadPointer(index + 1 + players_len,0));
    let (local x, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, remaining_data, read_pointer);
    let (local y, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 32, remaining_data, read_pointer);
    let (local type, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 2, remaining_data, read_pointer);
    let (local direction, remaining_data, read_pointer) = TuxitPacked.read_single(checkpoint_data_len, checkpoint_data, 2, remaining_data, read_pointer);
    
    assert shots[index] = Shot(id, x, y, type, direction);

    return load_shots_from_checkpoint(checkpoint_data_len, checkpoint_data, players_len, index + 1, shots_len, shots);
}


//Actions
@view
func load_and_verify_action{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    action: PackedAction,
    public_keys_len: felt,
    public_keys: felt*,
) -> (
    turn: felt,
    player_number: felt,
    key_code: felt,
    hash: felt,
    last_hash: felt
) {
    alloc_locals;

    //First, build back the action as an Array for easier interactions
    let (action_in_array: felt*) = alloc();
    assert action_in_array[0] = action.data;
    assert action_in_array[1] = action.last_hash;
    
    //Read the action data. This changes from game to game.
    let (turn, remaining_data, read_pointer) = TuxitPacked.read_single(1, action_in_array, 32, action_in_array[0], TuxitPacked.ReadPointer(0,0));
    let (player_number, remaining_data, read_pointer) = TuxitPacked.read_single(1, action_in_array, 3, remaining_data, read_pointer);
    let (key_code, remaining_data, read_pointer) = TuxitPacked.read_single(1, action_in_array, 8, remaining_data, read_pointer);
    
    //Finally, verify the hash the data with the provided signatures and the player number read from the data
    let hashed_data = TuxitPacked.hash_array(2, action_in_array);
    TuxitPacked.verify_signature(hashed_data, public_keys[player_number], action.signature);

    return (turn, player_number, key_code, hashed_data, action_in_array[1]);
}


//Game Logic
@view
func is_game_finished{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    public_keys_len: felt,
    public_keys: felt*,

    fixed_data_len: felt,
    fixed_data: felt*,
    fixed_signatures_len: felt,
    fixed_signatures: (felt, felt)*,

    checkpoint_data_len: felt,
    checkpoint_data: felt*,
    checkpoint_signatures_len: felt,
    checkpoint_signatures: (felt, felt)*,

    actions_len: felt,
    actions: PackedAction*,
) -> (
    finished: felt,
    winner: felt,
) {
    alloc_locals;
    let (grid_width, grid_area, map_len, map, total_players, player_indices_len, player_indices) = load_and_verify_fixed_state(fixed_data_len, fixed_data, public_keys_len, public_keys, fixed_signatures_len, fixed_signatures);
    let (turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = load_and_verify_checkpoint(checkpoint_data_len, checkpoint_data, public_keys_len, public_keys, checkpoint_signatures_len, checkpoint_signatures);
    let (turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = process_action_array(
        public_keys_len, public_keys,
        grid_width, map_len, map, player_indices_len, player_indices,
        turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash,
        actions_len, actions, 0);

    return (finished, winner);
}

@view
func process_action_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    public_keys_len: felt,
    public_keys: felt*,
    
    grid_width: felt,
    map_len: felt,
    map: felt*,
    player_indices_len: felt,
    player_indices: felt*,

    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt,

    actions_len: felt,
    actions: PackedAction*,

    index: felt
) -> (
    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt,
) {
    alloc_locals;

    if (index == actions_len) {
        return (turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash);
    }

    let (action_turn, player_number, key_code, action_hash, last_hash) = load_and_verify_action(actions[index], public_keys_len, public_keys);

    let (turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = process_action(
        grid_width, map_len, map, player_indices_len, player_indices,
        turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash,
        action_turn, player_number, key_code, action_hash, last_hash
    );

    return process_action_array(
        public_keys_len, public_keys,
        grid_width, map_len, map, player_indices_len, player_indices,
        turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash,
        actions_len, actions, index + 1);
}

func process_action{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    grid_width: felt,
    map_len: felt,
    map: felt*,
    player_indices_len: felt,
    player_indices: felt*,

    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt,

    action_turn: felt,
    player_number: felt,
    key_code: felt,
    action_hash: felt,
    last_hash: felt
) -> (
    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt
) {
    alloc_locals;

    //01. Check if number of players is ok among all variables
    with_attr error_message("Wrong players data") {
        assert player_indices_len = players_len;
        assert_nn_le(player_number, players_len);
    }

    //02.Check if the game is not already finished. If so, action is invalid.
    with_attr error_message("Game already finished") {
        assert finished = FALSE;
    }

    //03. Then, verify that the current turn number, player and last hash. If verification fails, action is invalid.
    with_attr error_message("Wrong action turn number") {
        assert action_turn = (turn + 1);
    }

    with_attr error_message("Wrong action last_hash") {
        assert last_hash = last_action_hash;
    }

    let (_, player_select) = unsigned_div_rem(action_turn, players_len);
    with_attr error_message("Wrong action player number") {
        assert player_indices[player_select] = player_number;
    }

    //04. Check if the player has moved and check if that move is valid
    let (current_player, has_moved, is_invalid_move) = player_move_result(player_number, players_len, players, grid_width, map_len, map, key_code);
    with_attr error_message("Invalid action") {
        assert is_invalid_move = FALSE;
    }

    if (has_moved == FALSE) {
        //05. If player hasn't moved, check if it has shot and add the shot in it's initial state
        let (current_player, last_shot, shots_len, shot) = player_shoot_result(current_player, last_shot, shots_len, shots, key_code);

        //06. If player hasn't moved or shot, action is invalid
        with_attr error_message("Invalid action") {
            assert shot = TRUE;
        }

        //07. Update the current player's remaining shots in the players array and proceed to the next function to evaluate shot movements and win conditions
        let (new_players_array: Player*) = alloc();
        update_player_array(player_number, current_player, players_len, players, players_len, new_players_array, 0);

        return process_shots(grid_width, map_len, map, action_turn, last_shot, players_len, new_players_array, shots_len, shots, player_number, action_hash, 0);
    } else {
        //05. Update the current player's position in the players array and go to the next function to evaluate shot movements and win conditions
        let (new_players_array: Player*) = alloc();
        update_player_array(player_number, current_player, players_len, players, players_len, new_players_array, 0);

        return process_shots(grid_width, map_len, map, action_turn, last_shot, players_len, new_players_array, shots_len, shots, player_number, action_hash, 0);
    }
}

func process_shots{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    grid_width: felt,
    map_len: felt,
    map: felt*,
    turn: felt,
    last_shot: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    player_number: felt,
    action_hash: felt,
    index: felt
) -> (
    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt
) {
    alloc_locals;

    //01. This function loops 4 times, moving shots by 1 tile each time, checking for collisions
    if (index == 4) {
        return check_win_conditions(grid_width, map_len, map, turn, last_shot, players_len, players, shots_len, shots, player_number, action_hash);
    }

    //02. Move shots and delete if out of grid
    let (new_shots: Shot*) = alloc();
    let new_shots_len = move_shots(grid_width, shots_len, shots, 0, new_shots, 0);

    //03. Check collisions with obstacles and players. If obstacle, delete. If player, set player.hit to true and delete the shot
    let (new_shots_without_collisions: Shot*) = alloc();
    let (players_len, players, new_shots_without_collisions_len) = find_shot_collisions(grid_width, map_len, map, players_len, players, new_shots_len, new_shots, 0, new_shots_without_collisions, 0);

    //04. Check collision between shots. If found, delete both shots (if shot hasn't hit a player)
    let (new_shots_without_intrashot_collisions: Shot*) = alloc();
    let new_shots_without_intrashot_collisions_len = find_intrashot_collisions(grid_width, new_shots_without_collisions_len, new_shots_without_collisions, 0, new_shots_without_intrashot_collisions, 0);

    return process_shots(grid_width, map_len, map, turn, last_shot, players_len, players, shots_len, shots, player_number, action_hash, index + 1);
}

func check_win_conditions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
    grid_width: felt,
    map_len: felt,
    map: felt*,
    turn: felt,
    last_shot: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    player_number: felt,
    action_hash: felt,
) -> (
    turn: felt,
    last_shot: felt,
    finished: felt,
    winner: felt,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    last_action_hash: felt
) {
    alloc_locals;
    
    //WIN CONDITION N°1: Reach another player's starting position
    let current_tile = tile_to_abs(Tile(players[player_number].x, players[player_number].y), grid_width);

    if (players[player_number].hit == FALSE) {
        let has_reached_goal = check_player_in_goal(grid_width, map_len, map, player_number, current_tile);
        if (has_reached_goal == TRUE) {
            return (turn, last_shot, TRUE, player_number, players_len, players, shots_len, shots, action_hash);
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    //WIN CONDITION N°1: Be the last player standing
    let (remaining_players: felt*) = alloc();
    let remaining_players_len = get_remaining_players(players_len, players, 0, remaining_players, 0);

    if (remaining_players_len == 1) {
        return (turn, last_shot, TRUE, remaining_players[0], players_len, players, shots_len, shots, action_hash);
    }
    
    return (turn, last_shot, FALSE, 0, players_len, players, shots_len, shots, action_hash);
}

func check_player_in_goal{syscall_ptr: felt*, range_check_ptr}(
    grid_width: felt,
    map_len: felt,
    map: felt*,
    player_number: felt,
    player_tile: felt,
) -> felt {
    alloc_locals;
    if (is_nn_le(5, map[player_tile]) == TRUE) {
        if (map[player_tile] != (5 + player_number)) {
            return TRUE;
        } else {
            return FALSE;
        }
    }
    return FALSE;
}

func get_remaining_players{syscall_ptr: felt*, range_check_ptr}(
    players_len: felt,
    players: Player*,
    remaining_len: felt,
    remaining: felt*,
    index: felt
) -> felt {
    if (index == players_len) {
        return remaining_len;
    }
    if (players[index].hit == FALSE) {
        assert remaining[remaining_len] = index;
        return get_remaining_players(players_len, players, remaining_len + 1, remaining, index + 1);
    }
    return get_remaining_players(players_len, players, remaining_len, remaining, index + 1);
}

func move_shots{syscall_ptr: felt*, range_check_ptr}(
    grid_width: felt,
    shots_len: felt,
    shots: Shot*,
    new_shots_len: felt,
    new_shots: Shot*,
    index: felt
) -> felt {
    if (index == shots_len) {
        return(new_shots_len);
    }
    
    if (shots[index].direction == 3) {
        if (shots[index].x != 0) {
            assert new_shots[new_shots_len] = Shot(
                shots[index].id, shots[index].x - 1, shots[index].y, shots[index].type, shots[index].direction
            );
            return move_shots(grid_width, shots_len, shots, new_shots_len + 1, new_shots, index + 1);
        } else {
            return move_shots(grid_width, shots_len, shots, new_shots_len, new_shots, index + 1);
        }
    }

    if (shots[index].direction == 2) {
        if (shots[index].y != 0) {
            assert new_shots[new_shots_len] = Shot(
                shots[index].id, shots[index].x, shots[index].y - 1, shots[index].type, shots[index].direction
            );
            return move_shots(grid_width, shots_len, shots, new_shots_len + 1, new_shots, index + 1);
        } else {
            return move_shots(grid_width, shots_len, shots, new_shots_len, new_shots, index + 1);
        }
    }

    if (shots[index].direction == 1) {
        if (is_nn_le(shots[index].x, (grid_width - 1)) == TRUE) {
            assert new_shots[new_shots_len] = Shot(
                shots[index].id, shots[index].x + 1, shots[index].y, shots[index].type, shots[index].direction
            );
            return move_shots(grid_width, shots_len, shots, new_shots_len + 1, new_shots, index + 1);
        } else {
            return move_shots(grid_width, shots_len, shots, new_shots_len, new_shots, index + 1);
        }
    }

    if (shots[index].direction == 0) {
        if (is_nn_le(shots[index].y, (grid_width - 1)) == TRUE) {
            assert new_shots[new_shots_len] = Shot(
                shots[index].id, shots[index].x, shots[index].y + 1, shots[index].type, shots[index].direction
            );
            return move_shots(grid_width, shots_len, shots, new_shots_len + 1, new_shots, index + 1);
        } else {
            return move_shots(grid_width, shots_len, shots, new_shots_len, new_shots, index + 1);
        }
    }

    with_attr error_message("Wrong shot data") {
        assert FALSE = TRUE;
    }

    return move_shots(grid_width, shots_len, shots, new_shots_len, new_shots, index + 1);
}

func find_shot_collisions{syscall_ptr: felt*, range_check_ptr}(
    grid_width: felt,
    map_len: felt,
    map: felt*,
    players_len: felt,
    players: Player*,
    shots_len: felt,
    shots: Shot*,
    new_shots_len: felt,
    new_shots: Shot*,
    index: felt
) -> (
    players_len: felt,
    players: Player*,
    shots_len: felt
) {
    alloc_locals;
    
    if (index == shots_len) {
        return(players_len, players, new_shots_len);
    }

    let tile = tile_to_abs(Tile(shots[index].x, shots[index].y), grid_width);
    let is_obstacle = is_tile_obstacle(map_len, map, tile);

    if (is_obstacle == TRUE) {
        return find_shot_collisions(grid_width, map_len, map, players_len, players, shots_len, shots, new_shots_len, new_shots, index + 1);
    } else {
        let (new_players: Player*) = alloc();
        let hit = check_player_hit(grid_width, players_len, players, 0, new_players, shots[index], 0, FALSE);
        if (hit == TRUE) {
            return find_shot_collisions(grid_width, map_len, map, players_len, players, shots_len, shots, new_shots_len, new_shots, index + 1);
        } else {
            assert new_shots[new_shots_len] = shots[index];
            return find_shot_collisions(grid_width, map_len, map, players_len, new_players, shots_len, shots, new_shots_len + 1, new_shots, index + 1);
        }
    }
}

func find_intrashot_collisions{syscall_ptr: felt*, range_check_ptr}(
    grid_width: felt,
    shots_len: felt,
    shots: Shot*,
    new_shots_len: felt,
    new_shots: Shot*,
    index: felt
) -> felt {
    alloc_locals;
    
    if (index == shots_len) {
        return(new_shots_len);
    }

    let current_tile = tile_to_abs(Tile(shots[index].x, shots[index].y), grid_width);
    let has_hit_another_shot = check_shot_collision(grid_width, shots_len, shots, shots[index].id, current_tile, 0, FALSE);

    if (has_hit_another_shot == FALSE) {
        assert new_shots[new_shots_len] = shots[index];
        return find_intrashot_collisions(grid_width, shots_len, shots, new_shots_len + 1, new_shots, index + 1);
    } else {
        return find_intrashot_collisions(grid_width, shots_len, shots, new_shots_len, new_shots, index + 1);
    }
}

func check_shot_collision{syscall_ptr: felt*, range_check_ptr}(
    grid_width: felt,
    shots_len: felt,
    shots: Shot*,
    current_shot_id: felt,
    current_tile: felt,
    index: felt,
    hit: felt
) -> felt {
    if (index == shots_len) {
        return hit;
    }

    let shot_tile = tile_to_abs(Tile(shots[index].x, shots[index].y), grid_width);
    if (shot_tile == current_tile) {
        if (shots[index].id != current_shot_id) {
            return check_shot_collision(grid_width, shots_len, shots, current_shot_id, current_tile, index + 1, TRUE);
        }
    }    

    return check_shot_collision(grid_width, shots_len, shots, current_shot_id, current_tile, index + 1, hit);
}

func is_tile_obstacle{syscall_ptr: felt*, range_check_ptr}(
    map_len: felt,
    map: felt*,
    tile: felt
) -> felt {
    if (map[tile] == 1) {
        return TRUE;
    }
    if (map[tile] == 4) {
        return TRUE;
    }
    return FALSE;
}

func check_player_hit{syscall_ptr: felt*, range_check_ptr}(
    grid_width: felt,
    players_len: felt,
    players: Player*,
    new_players_len: felt,
    new_players: Player*,
    shot: Shot,
    index: felt,
    hit: felt
) -> felt {
    alloc_locals;
    
    if (index == players_len) {
        return hit;
    }

    let tile_player = tile_to_abs(Tile(players[index].x, players[index].y), grid_width);
    let tile_shot = tile_to_abs(Tile(shot.x, shot.y), grid_width);

    if (tile_player == tile_shot) {
        assert new_players[new_players_len] = Player(
            players[index].x, players[index].y, players[index].orientation, TRUE,
            players[index].apples, players[index].oranges, players[index].pears
        );
        return check_player_hit(grid_width, players_len, players, new_players_len + 1, new_players, shot, index + 1, TRUE);
    } else {
        assert new_players[new_players_len] = players[index];
        return check_player_hit(grid_width, players_len, players, new_players_len + 1, new_players, shot, index + 1, hit);
    }
}

func update_player_array{syscall_ptr: felt*, range_check_ptr}(
    player_number: felt,
    current_player: Player,
    players_len: felt,
    players: Player*,
    new_players_len: felt,
    new_players_array: Player*,
    index: felt
) {
    if (index == players_len) {
        return();
    }
    if (index == player_number) {
        assert new_players_array[index] = current_player;
    } else {
        assert new_players_array[index] = players[index];
    }
    return update_player_array(player_number, current_player, players_len, players, players_len, new_players_array, index + 1);
}

func abs_to_tile{syscall_ptr: felt*, range_check_ptr}(
    abs_coord: felt,
    grid_width: felt
) -> Tile {
    let (y, x) = unsigned_div_rem(abs_coord, grid_width);
    let tile = Tile(x,y);
    return (tile);
}

func tile_to_abs(
    tile: Tile,
    grid_width: felt
) -> felt {
    return (tile.y * grid_width) + tile.x;
}

func player_move_result{syscall_ptr: felt*, range_check_ptr}(
    player_number: felt,
    players_len: felt,
    players: Player*,
    grid_width: felt,
    map_len: felt,
    map: felt*,
    key_code: felt
) -> (
    new_player: Player,
    moved: felt,
    invalid_move: felt
) {
    if (key_code == 37) {
        return can_move_to(player_number, Player(players[player_number].x - 1, players[player_number].y, players[player_number].orientation, players[player_number].hit, players[player_number].apples, players[player_number].oranges, players[player_number].pears), players_len, players, grid_width, map_len, map, key_code);
    }
    if (key_code == 38) {
        return can_move_to(player_number, Player(players[player_number].x, players[player_number].y - 1, players[player_number].orientation, players[player_number].hit, players[player_number].apples, players[player_number].oranges, players[player_number].pears), players_len, players, grid_width, map_len, map, key_code);
    }
    if (key_code == 39) {
        return can_move_to(player_number, Player(players[player_number].x + 1, players[player_number].y, players[player_number].orientation, players[player_number].hit, players[player_number].apples, players[player_number].oranges, players[player_number].pears), players_len, players, grid_width, map_len, map, key_code);
    }
    if (key_code == 40) {
        return can_move_to(player_number, Player(players[player_number].x, players[player_number].y + 1, players[player_number].orientation, players[player_number].hit, players[player_number].apples, players[player_number].oranges, players[player_number].pears), players_len, players, grid_width, map_len, map, key_code);
    }
    return (players[player_number], FALSE, FALSE);
}

func can_move_to{syscall_ptr: felt*, range_check_ptr}(
    player_number: felt,
    player: Player,
    players_len: felt,
    players: Player*,
    grid_width: felt,
    map_len: felt,
    map: felt*,
    key_code: felt
) -> (
    new_player: Player,
    moved: felt,
    invalid_move: felt
) {
    let tile = tile_to_abs(Tile(player.x, player.y), grid_width);
    let new_position_valid = can_walk_on_tile(map_len, map, tile);

    if (new_position_valid == TRUE) {
        return check_players_collision(player_number, Player(player.x, player.y, 40 - key_code, player.hit, player.apples, player.oranges, player.pears), players_len, players, grid_width, 0);
    } else {
        //TODO: Verify if using players[player_number] actually reverses the movement
        if (player.orientation == (40 - key_code)) {
            return (players[player_number], TRUE, TRUE);
        }
        return check_players_collision(player_number, Player(players[player_number].x, players[player_number].y, 40 - key_code, player.hit, player.apples, player.oranges, player.pears), players_len, players, grid_width, 0);
    }
}

func can_walk_on_tile{syscall_ptr: felt*, range_check_ptr}(
    map_len: felt,
    map: felt*,
    tile: felt
) -> felt {
    if (map[tile] == 0) {
        return FALSE;
    }
    if (map[tile] == 1) {
        return FALSE;
    }
    if (map[tile] == 4) {
        return FALSE;
    }
    return TRUE;
}

func check_players_collision{syscall_ptr: felt*, range_check_ptr}(
    player_number: felt,
    player: Player,
    players_len: felt,
    players: Player*,
    grid_width: felt,
    index: felt
) -> (
    new_player: Player,
    moved: felt,
    invalid_move: felt
) {
    if (index == players_len) {
        return (player, TRUE, FALSE);
    }

    if (index != player_number) {
        let tile_1 = tile_to_abs(Tile(player.x, player.y), grid_width);
        let tile_2 = tile_to_abs(Tile(players[index].x, players[index].y), grid_width);
        with_attr error_message("Player collision") {
            assert_not_equal(tile_1, tile_2);
        }
        return check_players_collision(player_number, player, players_len, players, grid_width, index + 1);
    }
    
    return check_players_collision(player_number, player, players_len, players, grid_width, index + 1);
}

func player_shoot_result{syscall_ptr: felt*, range_check_ptr}(
    player: Player,
    last_shot: felt,
    shots_len: felt,
    shots: Shot*,
    key_code: felt
) -> (
    new_player: Player,
    new_last_shot: felt,
    new_shots_len: felt,
    shot: felt
) {
    if (key_code == 90) {
        with_attr error_message("Not enough apples") {
            assert_nn_le(0, player.apples - 1);
        }
        assert shots[shots_len] = Shot(last_shot + 1, player.x, player.y, 0, player.orientation);
        return (Player(player.x, player.y, player.orientation, player.hit, player.apples - 1, player.oranges, player.pears), last_shot + 1, shots_len + 1, TRUE);
    }
    if (key_code == 88) {
        with_attr error_message("Not enough oranges") {
            assert_nn_le(0, player.oranges - 1);
        }
        assert shots[shots_len] = Shot(last_shot + 1, player.x, player.y, 1, player.orientation);
        return (Player(player.x, player.y, player.orientation, player.hit, player.apples, player.oranges - 1, player.pears), last_shot + 1, shots_len + 1, TRUE);
    }
    if (key_code == 67) {
        with_attr error_message("Not enough pears") {
            assert_nn_le(0, player.apples - 1);
        }
        assert shots[shots_len] = Shot(last_shot + 1, player.x, player.y, 2, player.orientation);
        return (Player(player.x, player.y, player.orientation, player.hit, player.apples, player.oranges, player.pears - 1), last_shot + 1, shots_len + 1, TRUE);
    }

    return (player, last_shot, shots_len, FALSE);
}
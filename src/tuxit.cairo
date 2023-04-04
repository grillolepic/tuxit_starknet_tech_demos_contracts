%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_lt, assert_le, assert_nn_le, split_felt
from starkware.cairo.common.math_cmp import is_nn_le, is_not_zero
from starkware.cairo.common.bool import TRUE, FALSE

struct PackedAction {
    data: felt,
    last_hash: felt,
    signature: (felt, felt),
}

@contract_interface
namespace ITuxitGame {
    func is_game_finished(public_keys_len: felt, public_keys: felt*,
        fixed_data_len: felt, fixed_data: felt*, fixed_signatures_len: felt, fixed_signatures: (felt, felt)*,
        checkpoint_data_len: felt, checkpoint_data: felt*, checkpoint_signatures_len: felt, checkpoint_signatures: (felt, felt)*,
        actions_len: felt, actions: PackedAction*,
    ) -> (finished: felt, winner: felt){
    }
}

struct Game {
    address: felt,
    name: felt,
    enabled: felt,
}

// GameRoom Status:
//   0: Created
//   1: All players joined
//   2: Randomness Set
//   3: Game started
//   4: Game in turn dispute?
//   5: Game in winner dispute?
//   6: Game finished with winner
//   7: ?
//   8: ?
//   9: ?
//   10: Game cancelled by creator before start

struct GameRoom {
    game_id: felt,
    players: felt,
    random_seed: felt,
    status: felt,
    winner: felt,
    join_deadline: felt,
}

//Owner
@storage_var
func Owner() -> (owner: felt) {
}

// Games
@storage_var
func TotalGames() -> (total: felt) {
}
@storage_var
func Games(game_id: felt) -> (game: Game) {
}

// Game Rooms
@storage_var
func TotalGameRooms() -> (total_game_rooms: felt) {
}
@storage_var
func GameRooms(room_id: felt) -> (room: GameRoom) {
}
@storage_var
func GameRoomJoinedPlayers(room_id: felt) -> (joined_players: felt) {
}
@storage_var
func GameRoomAddresses(room_id: felt, index: felt) -> (player_address: felt) {
}
@storage_var
func GameRoomPublicKeys(room_id: felt, index: felt) -> (public_key: felt) {
}
@storage_var
func PlayerTotalGameRooms(player_address: felt) -> (player_total_game_rooms: felt) {
}
@storage_var
func PlayerGameRoomsIndexed(player_address: felt, index: felt) -> (room_id: felt) {
}


@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    Owner.write(owner);
    //0x0123f9b8cb3e2a450cbd3538bd692b8fdfd2317310a7821c1f1bde4b95cea581
    Games.write(0, Game(0x070cedd0895472f56beca0c1d014e1e23f496e071548389fb1d945992015e6fc, 0x6d616e75616c436f6d706c657465, TRUE));
    TotalGames.write(1);
    return ();
}


// Create, Join, Exit Game Rooms
@external
func createRoom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    game_id: felt,
    players: felt,
    public_key: felt,
    time_to_expiry: felt
) {
    alloc_locals;

    let (total_rooms) = TotalGameRooms.read();
    let (caller) = get_caller_address();
    let (player_total_rooms) = PlayerTotalGameRooms.read(caller);
    let (ts) = get_block_timestamp();

    assert_previous_room_finished(caller);
    assert_game_exists_and_enabled(game_id);

    tempvar newRoom = GameRoom(game_id, players, 0, 0, 0, ts + time_to_expiry);

    TotalGameRooms.write(total_rooms + 1);
    GameRooms.write(total_rooms, newRoom);
    GameRoomJoinedPlayers.write(total_rooms, 1);
    GameRoomAddresses.write(total_rooms, 0, caller);
    GameRoomPublicKeys.write(total_rooms, 0, public_key);

    PlayerGameRoomsIndexed.write(caller, player_total_rooms, total_rooms);
    PlayerTotalGameRooms.write(caller, player_total_rooms + 1);

    //GameRoomCreated.emit(total_rooms);
    return ();
}

@external
func joinRoom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    room_id: felt, public_key: felt
) {
    alloc_locals;

    let (caller) = get_caller_address();
    let (player_total_rooms) = PlayerTotalGameRooms.read(caller);
    let (ts) = get_block_timestamp();

    let (game_room,_,_,_,_,_) = getGameRoom(room_id);

    with_attr error_message("Game Started") {
        assert game_room.status = 0;
    }

    with_attr error_message("Game Room Expired") {
        assert_le(ts, game_room.join_deadline);
    }

    with_attr error_message("Player2 equal to Player1") {
        assert_not_in_room(caller, room_id, game_room.players, 0);
    }

    assert_previous_room_finished(caller);

    let (playersJoined) = GameRoomJoinedPlayers.read(room_id);
    GameRoomAddresses.write(room_id, playersJoined, caller);
    GameRoomPublicKeys.write(room_id, playersJoined, public_key);
    GameRoomJoinedPlayers.write(room_id, playersJoined + 1);
    
    PlayerGameRoomsIndexed.write(caller, player_total_rooms, room_id);
    PlayerTotalGameRooms.write(caller, player_total_rooms + 1);

    if ((playersJoined + 1) == game_room.players) {

        let (prev_address) = GameRoomAddresses.read(room_id, playersJoined -1);
        let (random) = get_block_timestamp();
        let (random_hash_1) = hash2{hash_ptr=pedersen_ptr}(random, prev_address);
        let (random_hash_2) = hash2{hash_ptr=pedersen_ptr}(random_hash_1, caller);
        let (_, random_seed_128) = split_felt(random_hash_2);

        tempvar newRoom = GameRoom(game_room.game_id, game_room.players, random_seed_128, 3, 0, game_room.join_deadline);
        GameRooms.write(room_id, newRoom);

        //PlayerJoinedRoom.emit(room_id, caller);
        //GameStarted.emit(room_id);
        return();
    }

    return();
}

@external
func closeRoomBeforeStart{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(room_id: felt) {
    alloc_locals;

    let (game_room,_,_,_,_,_) = getGameRoom(room_id);

    with_attr error_message("Game Started") {
        assert game_room.status = 0;
    }

    with_attr error_message("Game Room Expired") {
        let (ts) = get_block_timestamp();
        assert_le(ts, game_room.join_deadline);
    }

    with_attr error_message("Only creator can close the room before start") {
        let (caller) = get_caller_address();
        let (creator) = GameRoomAddresses.read(room_id, 0);
        assert caller = creator;
    }

    tempvar newRoom = GameRoom(game_room.game_id, game_room.players, 0, 10, 0, 0);
    GameRooms.write(room_id, newRoom);

    //GameRoomCancelled.emit(room_id);
    return ();
}

@external
func verifyFinishedGameRoom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    room_id: felt,

    fixed_data_len: felt,
    fixed_data: felt*,
    fixed_signatures_len: felt,
    fixed_signatures: (felt, felt)*,

    checkpoint_data_len: felt,
    checkpoint_data: felt*,
    checkpoint_signatures_len: felt,
    checkpoint_signatures: (felt, felt)*,

    actions_len: felt,
    actions: PackedAction*
) {
    alloc_locals;

    let (game_room, game,_,_,_,_) = getGameRoom(room_id);
    let (caller) = get_caller_address();

    with_attr error_message("Game not started") {
        assert game_room.status = 3;
    }

    assert_in_room(caller, room_id, game_room.players, 0); 

    let (public_keys: felt*) = alloc();
    load_room_public_keys(room_id, game_room.players, 0, public_keys);

    let (finished, winner) = ITuxitGame.is_game_finished(
        game.address, 
        game_room.players,
        public_keys,
        fixed_data_len,
        fixed_data,
        fixed_signatures_len,
        fixed_signatures,
        checkpoint_data_len,
        checkpoint_data,
        checkpoint_signatures_len,
        checkpoint_signatures,
        actions_len,
        actions
    );

    with_attr error_message("Game not finished") {
        assert finished = TRUE;
    }

    tempvar newRoom = GameRoom(game_room.game_id, game_room.players, game_room.random_seed, 6, winner, game_room.join_deadline);
    GameRooms.write(room_id, newRoom);

    //PlayerWon.emit(room_id, caller);

    return ();
}


// Set and Retrive Games
@external
func addGame{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(game: Game) {
    assert_only_owner();
    let (totalGames) = TotalGames.read();
    TotalGames.write(totalGames + 1);
    updateGame(totalGames, game);
    return ();
}

@external
func updateGame{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(game_id: felt, game: Game) {
    assert_only_owner();
    let (totalGames) = TotalGames.read();
    with_attr error_message("Game doesn't exist") {
        assert_nn_le(game_id, totalGames - 1);
    }
    Games.write(game_id, game);
    return ();
}

@view
func getGame{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(game_id: felt) -> (game: Game) {
    let (totalGames) = TotalGames.read();
    with_attr error_message("Game doesn't exist") {
        assert_nn_le(game_id, totalGames - 1);
    }
    let (game) = Games.read(game_id);
    return (game = game);
}


// Retrive Game Rooms
@view
func getPlayerCurrentRoom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(player: felt) -> (room_id: felt, game_room: GameRoom, game: Game) {
    alloc_locals;
    let (total_rooms) = getPlayerTotalRooms(player);
    with_attr error_message("Caller has not created or joined any Game Room") {
        assert_nn_le(1, total_rooms);
    }

    let (room_id) = PlayerGameRoomsIndexed.read(player, total_rooms - 1);
    let (game_room,game,_,_,_,_) = getGameRoom(room_id);
    
    if (game_room.status == 0) {
        let (ts) = get_block_timestamp();
        with_attr error_message("Player's last Game Room expired") {
            assert_le(ts, game_room.join_deadline);
        }
        return (room_id, game_room, game);
    } else {
        with_attr error_message("Player's last Game Room finished") {
            assert_le(game_room.status, 5);
        }
        return (room_id, game_room, game);
    }
}

@view
func getTotalRooms{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (total: felt) {
    let (total) = TotalGameRooms.read();
    return (total,);
}

@view
func getGameRoom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(room_id: felt) -> (room: GameRoom, game: Game, player_addresses_len: felt, player_addresses: felt*, public_keys_len: felt, public_keys: felt*) {
    alloc_locals;

    let (total_rooms) = TotalGameRooms.read();
    with_attr error_message("Room Not found") {
        assert_nn_le(room_id, total_rooms - 1);
    }

    let (game_room) = GameRooms.read(room_id);
    let (game) = Games.read(game_room.game_id);

    let (player_addresses:felt*) = alloc();
    load_room_player_addresses(room_id, game_room.players, 0, player_addresses);

    let (public_keys:felt*) = alloc();
    load_room_public_keys(room_id, game_room.players, 0, public_keys);

    return (game_room, game, game_room.players, player_addresses, game_room.players, public_keys);
}

@view
func getPlayerTotalRooms{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(player: felt) -> (total: felt) {
    let (total) = PlayerTotalGameRooms.read(player);
    return (total=total);
}

@view
func getPlayerGameRoomByIndex{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(player: felt, index: felt) -> (room_id: felt) {
    let (totalPlayerRooms) = PlayerTotalGameRooms.read(player);
    with_attr error_message("Player's Room Not found") {
        assert_nn_le(index, totalPlayerRooms - 1);
    }
    let (room_id) = PlayerGameRoomsIndexed.read(player, index);
    return (room_id,);
}


// Internal Functions
func assert_previous_room_finished{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(caller: felt) {
    alloc_locals;

    let (player_total_rooms) = PlayerTotalGameRooms.read(caller);

    if (player_total_rooms != 0) {
        let (lastCallerroom_id) = PlayerGameRoomsIndexed.read(caller, player_total_rooms - 1);
        let (game_room) = GameRooms.read(lastCallerroom_id);

        if (game_room.status == 0) {
            let (ts) = get_block_timestamp();
            with_attr error_message("Player's previous Game Room Not Expired") {
                assert_le(game_room.join_deadline, ts);
            }
            return ();
        } else {
            with_attr error_message("Previous Player Game Room Not Finished") {
                assert_le(6, game_room.status);
            }
            return ();
        }
    } else {
        return ();
    }
}

func assert_game_exists_and_enabled{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(game_id: felt) {
    let (totalGames) = TotalGames.read();
    with_attr error_message("Game doesn't exist") {
        assert_nn_le(game_id, totalGames - 1);
    }
    let (game) = Games.read(game_id);
    with_attr error_message("Game not enabled") {
        assert game.enabled = TRUE;
    }
    return ();
}

func assert_not_in_room{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(caller: felt, room_id: felt, players: felt, index: felt) {
    if (index == players) {
        return();
    }
    let (player_address) = GameRoomAddresses.read(room_id, index);
    with_attr error_message("Caller already in Game Room") {
        assert_not_equal(player_address, caller);
    }
    return assert_not_in_room(caller, room_id, players, index + 1);
}

func assert_only_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller) = get_caller_address();
    let (owner) = Owner.read();
    with_attr error_message("Not owner") {
        assert owner = caller;
    }
    return ();
}

func assert_in_room{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(caller: felt, room_id: felt, players: felt, index: felt) {
    if (index == players) {
        with_attr error_message("Caller not in Game Room") {
            assert 0 = 1;
        }
        return();
    }
    let (player_address) = GameRoomAddresses.read(room_id, index);
    if (player_address == caller) {
        return();
    } else {
        return assert_in_room(caller, room_id, players, index + 1);
    }
}

func load_room_public_keys{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(room_id: felt, players: felt, public_keys_len: felt, public_keys: felt*) {
    if (public_keys_len == players) {
        return();
    }
    let (key) = GameRoomPublicKeys.read(room_id, public_keys_len);
    assert public_keys[public_keys_len] = key;
    return load_room_public_keys(room_id, players, public_keys_len + 1, public_keys);
}

func load_room_player_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(room_id: felt, players: felt, player_addresses_len: felt, player_addresses: felt*) {
    if (player_addresses_len == players) {
        return();
    }
    let (address) = GameRoomAddresses.read(room_id, player_addresses_len);
    assert player_addresses[player_addresses_len] = address;
    return load_room_player_addresses(room_id, players, player_addresses_len + 1, player_addresses);
}
%lang starknet
from starkware.cairo.common.alloc import alloc
from src.manualComplete import load_and_verify_fixed_state, load_and_verify_checkpoint, process_action_array, PackedAction
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.bool import TRUE, FALSE

@external
func test_execute_game_turns{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}() {
    alloc_locals;

    //Public Keys
    let (public_keys: felt*) = alloc();
    assert public_keys[0] = 0x07baa6f6f4ac308e9eccce1e8afc4f8228830e050097f443b9b08959999d771a;
    assert public_keys[1] = 0x069e6b1675850c17e638823674de8b0e5fe07142d045c0a812e054be3c14ccae;
    let public_keys_len = 2;

    //Fixed State
    let (fixed_data: felt*) = alloc();
    assert fixed_data[0] = 0x490000000000000200010010;
    assert fixed_data[1] = 0x8092492408490092492008490095890;
    assert fixed_data[2] = 0x12498012012090090012002519090002;
    assert fixed_data[3] = 0x24a24a440000049a492092000482490;
    assert fixed_data[4] = 0x1b6db4800936db6db48009b6db6d2080;
    assert fixed_data[5] = 0x100800249249000849272369200259b;
    assert fixed_data[6] = 0x42000000000;
    let fixed_data_len = 7;

    let (fixed_signatures: (felt, felt)*) = alloc();
    assert fixed_signatures[0] = (0x320acbbaf6071a1e7e7f138ef16750b18399ef4cc6aefe52740c04340a2a955, 0x83d8a5435aea89b854eb3337fd8c15bc4159b7caf84b65b5cb40c4bcc557b5);
    assert fixed_signatures[1] = (0x3efb6ab4ea8225990d413abf47b2c7fb5c5967e65f3a4ad1190c87a0c708d0, 0x219f81f05fe79b770125f34083c0080838606526a65661af70a8eec7f9ed01b);

    //Checkpoint
    let (checkpoint_data: felt*) = alloc();
    assert checkpoint_data[0] = 0x1e;
    assert checkpoint_data[1] = 0x10002000410000000b0000000c;
    assert checkpoint_data[2] = 0x10002000420000000b00000008;
    assert checkpoint_data[3] = 0x49ddf01851c443a0f163edc6ba4d9cf32cf5c6b9c03132fb1b76ecc2fd8d4f8;
    let checkpoint_data_len = 4;

    let (checkpoint_signatures: (felt, felt)*) = alloc();
    assert checkpoint_signatures[0] = (0x24de2fbb95654a578825702207310ac5821a5ab824d5bd4c94f541179ba72b2, 0x2e1e9c6e41dadfd46a63c52ffe43f17a6ff2f26b4672585cd7e6d5b46c95182);
    assert checkpoint_signatures[1] = (0x391dc248efca124b72c9774317b34539c28d685b61abf022adfb995ea4768d9, 0x2d0f221f8c33bfba6d5330d0a16e0ccf40e33e8c407bce84432f13d240244fc);

    //Actions
    let (actions: PackedAction*) = alloc();
    assert actions[0] = PackedAction(
        0x1410000001f, 0x49ddf01851c443a0f163edc6ba4d9cf32cf5c6b9c03132fb1b76ecc2fd8d4f8,
        (0x2c0327c38abb9ea69bf6635e8618e49b180fa07eeb203f7ea9f11983dbc921d, 0x7e5dcdb9a1c2158d9294405fa5f75643ba90ad8ffa2d4abeb1d50508afe740a)
    );
    assert actions[1] = PackedAction(
        0x14000000020, 0x197ea839bbf91635b2f398f72c69c7f42e53f252b2cb759862f6efdbe5a1e20,
        (0x24175dd41bd0c8f1e61660acbbf77e470adcce697dbc0b44f6114cc3c2a7dde, 0x66c097a1c8b661648ec19e1d841d45d9d6a8097a6d771627d7706477daaf64f)
    );
    let actions_len = 2;


    //Calculate Game State
    let (grid_width, grid_area, map_len, map, total_players, player_indices_len, player_indices) = load_and_verify_fixed_state(fixed_data_len, fixed_data, public_keys_len, public_keys, 2, fixed_signatures);
    let (turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = load_and_verify_checkpoint(checkpoint_data_len, checkpoint_data, public_keys_len, public_keys, 2, checkpoint_signatures);
    let (fturn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = process_action_array(
        public_keys_len, public_keys,
        grid_width, map_len, map, player_indices_len, player_indices,
        turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash,
        actions_len, actions, 0);

    %{
        print(f'finished: {ids.finished}')
        print(f'winner: {ids.winner}')
    %}

    return ();
}
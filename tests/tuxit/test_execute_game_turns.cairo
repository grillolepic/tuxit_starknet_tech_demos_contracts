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
    assert public_keys[0] = 0x03e7bb9d23d8f135c25c8ceea388195b5e8ffdebdc89b231b2790bda7dacddf5;
    assert public_keys[1] = 0x04d2bace24fb8f9670cb822437e0ce40ccbed0bd59f58936cac8ba2b9f1a3262;
    let public_keys_len = 2;

    //Fixed State
    let (fixed_data: felt*) = alloc();
    assert fixed_data[0] = 0x490000000000000000010010;
    assert fixed_data[1] = 0x24924800000124924c8000002492480;
    assert fixed_data[2] = 0x12540200492490000200490510000002;
    assert fixed_data[3] = 0x249249b6da24289289b692002490712;
    assert fixed_data[4] = 0x1b6db4800936db6db68009b4936e3680;
    assert fixed_data[5] = 0x24924800001936db69200249b;
    assert fixed_data[6] = 0xa000000000;
    let fixed_data_len = 7;

    let (fixed_signatures: (felt, felt)*) = alloc();
    assert fixed_signatures[0] = (0x1ae9cb2c46e55ad54c117ac3bd04d7fb53254cc821832904dc81c58c9eb184b, 0x251cb9de42587a94f3d21992612291ae6f44b412f0873f159a62d8294c4345);
    assert fixed_signatures[1] = (0x13645fd1bc84362cc3ce0ce66f2a0f5e7c96583a8d64e4f2e77927c5f2806f7, 0xba38c6393f7a0763ee38cdf8577288a68a10f37b93403dacde7d7ac046a80e);

    //Checkpoint
    let (checkpoint_data: felt*) = alloc();
    assert checkpoint_data[0] = 0x0;
    assert checkpoint_data[1] = 0x10002000420000000700000002;
    assert checkpoint_data[2] = 0x10002000430000000d0000000c;
    assert checkpoint_data[3] = 0x0;
    let checkpoint_data_len = 4;

    let (checkpoint_signatures: (felt, felt)*) = alloc();
    assert checkpoint_signatures[0] = (0xbcff6b6b596216aef07b58bf619a785b039ac12aeb7035bb5b1fb121699bfe, 0x110d8bfc22ddc019a2e667dba96284933fe8d56733ff1c49dcb2771fc72a974);
    assert checkpoint_signatures[1] = (0x2fc7b546073aa9317c3b0a742228e81f96e98ac91d8152ccdc3da747a8f4684, 0x44edd4fd21ed0db3ab543bcc7c65b4e803e9fbd8e297388a52851b5b303d119);

    //Actions
    let (actions: PackedAction*) = alloc();
    assert actions[0] = PackedAction(
        0x14000000001, 0x0,
        (0x1ad78cb9c5c77e93d75374f4db24e1ae4a2f0f27a25d13d3c75d7b55a686a2f, 0x3a3bf7afde863c587330c479ed534c26d32249415b606451703493bbf8b1d45)
    );
    assert actions[1] = PackedAction(
        0x13100000002, 0xa77a13627f9af4bfeeac367f234d6e577eab8974dd4055289c9ddacbad1450,
        (0x43266d00a173fa76749da7e7271cee69adb63b5fa496142e721fbe363dbbb12, 0xd21ce5848402b5b46e078d9892f27dfac3bf6345f3af2b01fcced342828afd)
    );
    assert actions[2] = PackedAction(
        0x13800000003, 0x373db541927a7935e952b3030fd3674566d0d52d5f2bf0938b2d5d0a3db610,
        (0x7de55df6a79952af731b8a5f48a42b7e80b28edb37829649fbfc1e5bd31763f, 0x2544eb36777f085737898bb000f02384ecfbce1b2dfcc3d44fb7d61805acf9d)
    );
    assert actions[3] = PackedAction(
        0x12900000004, 0x3e0bda2f22e1f42432e77011535ed4c859316366025b0aa724e6afbbd807d01,
        (0x5cd7801c2f1f87e5833f84367ab687e071c1f389b29dd812ad9c576fde4bfd6, 0x62e372e68042660aa8e2fea270650e43605982f679edcb70f3706bb3836c7ea)
    );
    assert actions[4] = PackedAction(
        0x2d000000005, 0x4b1f6f607b4722660c1e7bbbc9de4f6cfeb5dd3e620a5c4fccc4e583948e0f1,
        (0x31fe7e4026ef2a2820d692b4f273c05694e97308c75d910d5fb657ef09dea3, 0x473ec35a355b6a968d3e45c00c132c967c3a9b576e3b98832ac847610f3d05b)
    );
    assert actions[5] = PackedAction(
        0x12900000006, 0x8f6461968280437829afb3bcb587e937b4a3ddba0c8a8d6063880cf41c2962,
        (0x4ec446869326f4b00565de1189728d8efe633705c004d0ece7dd5a79be1a5aa, 0x3880c980228d442cc102400d3b689dc98ac2dd360a58ef2a185949b11a63a57)
    );
    assert actions[6] = PackedAction(
        0x14000000007, 0x35028113e046bd7c15c2f1165148e9101a1ea2d79eeb478361e0f260256ea20,
        (0x741cbb510a69c9789e1be0c49ac38540f0c9b55898f3ad921ebdfaeca3613a0, 0x7352f4e45807ab2cc181d48c53c2431c83869c7e4a4f3bf4f0273fcc84f3bad)
    );
    assert actions[7] = PackedAction(
        0x13100000008, 0x4ac80b2827e6c73f24c26be353a403c4d412faf2b73156766c90ca93d5a2f9e,
        (0x45a18214df1769db09f4d106444889091314a838f487709fb30ddc0e063d3fa, 0x65c5a40ed13384a69a979117f3ea9d70543491a367efcb678f61107ca5a88e6)
    );
    let actions_len = 8;

    //Calculate Game State
    let (grid_width, grid_area, map_len, map, total_players, player_indices_len, player_indices) = load_and_verify_fixed_state(fixed_data_len, fixed_data, public_keys_len, public_keys, 2, fixed_signatures);
    let (turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = load_and_verify_checkpoint(checkpoint_data_len, checkpoint_data, public_keys_len, public_keys, 2, checkpoint_signatures);
    let (fturn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash) = process_action_array(
        public_keys_len, public_keys,
        grid_width, map_len, map, player_indices_len, player_indices,
        turn, last_shot, finished, winner, players_len, players, shots_len, shots, last_action_hash,
        actions_len, actions, 0);

    return ();
}
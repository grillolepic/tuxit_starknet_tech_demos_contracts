%lang starknet
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from src.tuxit import Game
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.bool import TRUE, FALSE

@contract_interface
namespace TuxitContract {
    func createRoom(game_id: felt, players: felt, public_key: felt, time_to_expiry: felt) {
    }
    func joinRoom(room_id: felt, public_key: felt) {
    }
    func closeRoomBeforeStart(room_id: felt) {
    }
    func addGame(game: Game) {
    }
    func getGame(game_id: felt) -> (game: Game) {
    }
}

@external
func test_manage_rooms{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*}() {
    alloc_locals;

    local tuxit_contract_address: felt;
    local manualComplete_contract_address: felt;

    let (owner_address) = get_caller_address();
    
    %{
        print(f'Owner Address is {ids.owner_address}')
        ids.tuxit_contract_address = deploy_contract("./src/tuxit.cairo", [ids.owner_address]).contract_address
        print(f'Tuxit Contract deployed to {hex(ids.tuxit_contract_address)}')

        ids.manualComplete_contract_address = deploy_contract("./src/manualComplete.cairo").contract_address
        print(f'manualComplete Contract deployed to {hex(ids.manualComplete_contract_address)}')
    %}

    TuxitContract.addGame(tuxit_contract_address, Game(manualComplete_contract_address, 0, TRUE));
    


    return ();
}
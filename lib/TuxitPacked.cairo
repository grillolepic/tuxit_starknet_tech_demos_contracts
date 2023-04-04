%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.bool import TRUE, FALSE

namespace TuxitPacked {

    struct ReadPointer {
        index: felt,
        position: felt,
    }

    const DATA_LENGTH = 128;

    @view
    func hash_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        data_len: felt,
        data: felt*,
    ) -> felt {
        let result = hash_loop(data_len, data, 0, 0);
        return result;
    }

    func hash_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        data_len: felt,
        data: felt*,
        index: felt,
        last_hash: felt
    ) -> felt {
        if (index == data_len) {
            return last_hash;
        }
        let (next_hash) = hash2{hash_ptr=pedersen_ptr}(last_hash, data[index]);
        return hash_loop(data_len, data, index + 1, next_hash);
    }


    @view
    func verify_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
        hashed_data: felt,
        public_key: felt,
        signature: (felt, felt),
    ) {
        verify_ecdsa_signature(hashed_data, public_key, signature[0], signature[1]);
        return();
    }

    @view
    func verify_signatures{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
        hashed_data: felt,
        public_keys_len: felt,
        public_keys: felt*,
        signatures_len: felt,
        signatures: (felt, felt)*,
    ) {
        return verify_loop(hashed_data, 0, public_keys_len, public_keys, signatures_len, signatures);
    }

    func verify_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*}(
        hashed_data: felt,
        index: felt,
        public_keys_len: felt,
        public_keys: felt*,
        signatures_len: felt,
        signatures: (felt, felt)*,
    ) {
        if (index == public_keys_len) {
            return();
        }
        verify_ecdsa_signature(hashed_data, public_keys[index], signatures[index][0], signatures[index][1]);
        return verify_loop(hashed_data, index + 1, public_keys_len, public_keys, signatures_len, signatures);
    }
 
 
    @view
    func read_single{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        original_data_len: felt,
        original_data: felt*,
        bit_length: felt,
        last_remaining_data: felt,
        last_read_pointer: ReadPointer,
    ) -> (
        value: felt,
        new_remaining_data: felt,
        new_read_pointer: ReadPointer
    ) {
        alloc_locals;
        let bits_remaining_ok = is_nn_le(last_read_pointer.position + bit_length, DATA_LENGTH);
        let (div) = pow2(bit_length);
        
        if (bits_remaining_ok == FALSE) {
            with_attr error_message("Index Overflow") {
                assert_nn_le(last_read_pointer.index + 1, original_data_len);
            }
            let next_index = last_read_pointer.index + 1;
            let read_pointer = ReadPointer(next_index, 0);
            let remaining_data = original_data[next_index];
            let (remaining_left_bits, right_bits) = unsigned_div_rem(remaining_data, div);
            let (new_read_pointer) = next_position(read_pointer, bit_length, original_data_len);
            return (right_bits, remaining_left_bits, new_read_pointer);
        } else {
            let (remaining_left_bits, right_bits) = unsigned_div_rem(last_remaining_data, div);
            let (new_read_pointer) = next_position(last_read_pointer, bit_length, original_data_len);
            return (right_bits, remaining_left_bits, new_read_pointer);
        }
    }

    @view
    func read_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        original_data_len: felt,
        original_data: felt*,
        bit_length: felt,
        last_remaining_data: felt,
        last_read_pointer: ReadPointer,
        target_len: felt,
        result_data_len: felt,
        result_data: felt*,
    ) -> (
        new_remaining_data: felt,
        new_read_pointer: ReadPointer
    ) {
        alloc_locals;
        if (result_data_len == target_len) {
            return (last_remaining_data, last_read_pointer);
        }
        let (value, remaining_data, read_pointer) = read_single(original_data_len, original_data, bit_length, last_remaining_data, last_read_pointer);
        assert result_data[result_data_len] = value;
        return read_array(original_data_len, original_data, bit_length, remaining_data, read_pointer, target_len, result_data_len + 1, result_data);
    }

    func next_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        last_read_pointer: ReadPointer,
        bit_length: felt,
        max_index: felt
    ) -> (
        new_read_pointer: ReadPointer
    ) {
        with_attr error_message("Index Overflow") {
            assert_nn_le(last_read_pointer.index, max_index);
        }
        tempvar _new_position = last_read_pointer.position + bit_length;
        let _position_overflow = is_nn_le(DATA_LENGTH, _new_position);
        if (_position_overflow == TRUE) {
            let result_read_pointer = ReadPointer(last_read_pointer.index + 1, 0);
            return (new_read_pointer = result_read_pointer);
        }
        let result_read_pointer = ReadPointer(last_read_pointer.index, _new_position);
        return (new_read_pointer = result_read_pointer);
    }

    func pow2(i: felt) -> (res: felt) {
        let (data_address) = get_label_location(data);
        return ([data_address + i],);
        data:
        dw 1;
        dw 2;
        dw 4;
        dw 8;
        dw 16;
        dw 32;
        dw 64;
        dw 128;
        dw 256;
        dw 512;
        dw 1024;
        dw 2048;
        dw 4096;
        dw 8192;
        dw 16384;
        dw 32768;
        dw 65536;
        dw 131072;
        dw 262144;
        dw 524288;
        dw 1048576;
        dw 2097152;
        dw 4194304;
        dw 8388608;
        dw 16777216;
        dw 33554432;
        dw 67108864;
        dw 134217728;
        dw 268435456;
        dw 536870912;
        dw 1073741824;
        dw 2147483648;
        dw 4294967296;
        dw 8589934592;
        dw 17179869184;
        dw 34359738368;
        dw 68719476736;
        dw 137438953472;
        dw 274877906944;
        dw 549755813888;
        dw 1099511627776;
        dw 2199023255552;
        dw 4398046511104;
        dw 8796093022208;
        dw 17592186044416;
        dw 35184372088832;
        dw 70368744177664;
        dw 140737488355328;
        dw 281474976710656;
        dw 562949953421312;
        dw 1125899906842624;
        dw 2251799813685248;
        dw 4503599627370496;
        dw 9007199254740992;
        dw 18014398509481984;
        dw 36028797018963968;
        dw 72057594037927936;
        dw 144115188075855872;
        dw 288230376151711744;
        dw 576460752303423488;
        dw 1152921504606846976;
        dw 2305843009213693952;
        dw 4611686018427387904;
        dw 9223372036854775808;
        dw 18446744073709551616;
        dw 36893488147419103232;
        dw 73786976294838206464;
        dw 147573952589676412928;
        dw 295147905179352825856;
        dw 590295810358705651712;
        dw 1180591620717411303424;
        dw 2361183241434822606848;
        dw 4722366482869645213696;
        dw 9444732965739290427392;
        dw 18889465931478580854784;
        dw 37778931862957161709568;
        dw 75557863725914323419136;
        dw 151115727451828646838272;
        dw 302231454903657293676544;
        dw 604462909807314587353088;
        dw 1208925819614629174706176;
        dw 2417851639229258349412352;
        dw 4835703278458516698824704;
        dw 9671406556917033397649408;
        dw 19342813113834066795298816;
        dw 38685626227668133590597632;
        dw 77371252455336267181195264;
        dw 154742504910672534362390528;
        dw 309485009821345068724781056;
        dw 618970019642690137449562112;
        dw 1237940039285380274899124224;
        dw 2475880078570760549798248448;
        dw 4951760157141521099596496896;
        dw 9903520314283042199192993792;
        dw 19807040628566084398385987584;
        dw 39614081257132168796771975168;
        dw 79228162514264337593543950336;
        dw 158456325028528675187087900672;
        dw 316912650057057350374175801344;
        dw 633825300114114700748351602688;
        dw 1267650600228229401496703205376;
        dw 2535301200456458802993406410752;
        dw 5070602400912917605986812821504;
        dw 10141204801825835211973625643008;
        dw 20282409603651670423947251286016;
        dw 40564819207303340847894502572032;
        dw 81129638414606681695789005144064;
        dw 162259276829213363391578010288128;
        dw 324518553658426726783156020576256;
        dw 649037107316853453566312041152512;
        dw 1298074214633706907132624082305024;
        dw 2596148429267413814265248164610048;
        dw 5192296858534827628530496329220096;
        dw 10384593717069655257060992658440192;
        dw 20769187434139310514121985316880384;
        dw 41538374868278621028243970633760768;
        dw 83076749736557242056487941267521536;
        dw 166153499473114484112975882535043072;
        dw 332306998946228968225951765070086144;
        dw 664613997892457936451903530140172288;
        dw 1329227995784915872903807060280344576;
        dw 2658455991569831745807614120560689152;
        dw 5316911983139663491615228241121378304;
        dw 10633823966279326983230456482242756608;
        dw 21267647932558653966460912964485513216;
        dw 42535295865117307932921825928971026432;
        dw 85070591730234615865843651857942052864;
        dw 170141183460469231731687303715884105728;
        dw 340282366920938463463374607431768211456;
    }
}
// This file was autogenerated by some hot garbage in the `uniffi` crate.
// Trust me, you don't want to mess with it!

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// The following structs are used to implement the lowest level
// of the FFI, and thus useful to multiple uniffied crates.
// We ensure they are declared exactly once, with a header guard, UNIFFI_SHARED_H.
#ifdef UNIFFI_SHARED_H
    // We also try to prevent mixing versions of shared uniffi header structs.
    // If you add anything to the #else block, you must increment the version suffix in UNIFFI_SHARED_HEADER_V4
    #ifndef UNIFFI_SHARED_HEADER_V4
        #error Combining helper code from multiple versions of uniffi is not supported
    #endif // ndef UNIFFI_SHARED_HEADER_V4
#else
#define UNIFFI_SHARED_H
#define UNIFFI_SHARED_HEADER_V4
// ⚠️ Attention: If you change this #else block (ending in `#endif // def UNIFFI_SHARED_H`) you *must* ⚠️
// ⚠️ increment the version suffix in all instances of UNIFFI_SHARED_HEADER_V4 in this file.           ⚠️

typedef struct RustBuffer
{
    int32_t capacity;
    int32_t len;
    uint8_t *_Nullable data;
} RustBuffer;

typedef int32_t (*ForeignCallback)(uint64_t, int32_t, const uint8_t *_Nonnull, int32_t, RustBuffer *_Nonnull);

// Task defined in Rust that Swift executes
typedef void (*UniFfiRustTaskCallback)(const void * _Nullable);

// Callback to execute Rust tasks using a Swift Task
//
// Args:
//   executor: ForeignExecutor lowered into a size_t value
//   delay: Delay in MS
//   task: UniFfiRustTaskCallback to call
//   task_data: data to pass the task callback
typedef void (*UniFfiForeignExecutorCallback)(size_t, uint32_t, UniFfiRustTaskCallback _Nullable, const void * _Nullable);

typedef struct ForeignBytes
{
    int32_t len;
    const uint8_t *_Nullable data;
} ForeignBytes;

// Error definitions
typedef struct RustCallStatus {
    int8_t code;
    RustBuffer errorBuf;
} RustCallStatus;

// ⚠️ Attention: If you change this #else block (ending in `#endif // def UNIFFI_SHARED_H`) you *must* ⚠️
// ⚠️ increment the version suffix in all instances of UNIFFI_SHARED_HEADER_V4 in this file.           ⚠️
#endif // def UNIFFI_SHARED_H

// Callbacks for UniFFI Futures
typedef void (*UniFfiFutureCallbackUInt64)(const void * _Nonnull, uint64_t, RustCallStatus);
typedef void (*UniFfiFutureCallbackRustBuffer)(const void * _Nonnull, RustBuffer, RustCallStatus);

// Scaffolding functions
RustBuffer uniffi_sphinxrs_fn_func_pubkey_from_secret_key(RustBuffer my_secret_key, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_derive_shared_secret(RustBuffer their_pubkey, RustBuffer my_secret_key, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_encrypt(RustBuffer plaintext, RustBuffer secret, RustBuffer nonce, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_decrypt(RustBuffer ciphertext, RustBuffer secret, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_node_keys(RustBuffer net, RustBuffer seed, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_mnemonic_from_entropy(RustBuffer entropy, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_entropy_from_mnemonic(RustBuffer mnemonic, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_mnemonic_to_seed(RustBuffer mnemonic, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_entropy_to_seed(RustBuffer entropy, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_build_request(RustBuffer msg, RustBuffer secret, uint64_t nonce, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_parse_response(RustBuffer res, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_make_auth_token(uint32_t ts, RustBuffer secret, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_run(RustBuffer topic, RustBuffer args, RustBuffer state, RustBuffer msg1, RustBuffer expected_sequence, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_sha_256(RustBuffer msg, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_create_onion(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer hops, RustBuffer payload, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_create_onion_msg(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer hops, RustBuffer json, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_create_keysend(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer hops, uint64_t msat, RustBuffer rhash, RustBuffer payload, uint32_t curr_height, RustBuffer preimage, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_create_keysend_msg(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer hops, uint64_t msat, RustBuffer rhash, RustBuffer msg_json, uint32_t curr_height, RustBuffer preimage, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_peel_onion(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer payload, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_peel_onion_msg(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer payload, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_peel_payment(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer payload, RustBuffer rhash, uint32_t cur_height, uint32_t cltv_expiry, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_peel_payment_msg(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer payload, RustBuffer rhash, uint32_t cur_height, uint32_t cltv_expiry, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_sign_ms(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_signed_timestamp(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_sign_bytes(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer msg, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_sign_base64(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustBuffer msg, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_pubkey_from_seed(RustBuffer seed, uint64_t idx, RustBuffer time, RustBuffer network, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_root_sign_ms(RustBuffer seed, RustBuffer time, RustBuffer network, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_xpub_from_seed(RustBuffer seed, RustBuffer time, RustBuffer network, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_set_network(RustBuffer network, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_set_device(RustBuffer device, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_set_blockheight(uint32_t blockheight, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_blockheight(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_add_contact(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer to_pubkey, RustBuffer route_hint, RustBuffer my_alias, RustBuffer my_img, uint64_t amt_msat, RustBuffer invite_code, RustBuffer their_alias, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_contact(RustBuffer state, RustBuffer pubkey, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_list_contacts(RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_contact_pubkey_by_child_index(RustBuffer state, uint64_t child_idx, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_contact_pubkey_by_encrypted_child(RustBuffer seed, RustBuffer state, RustBuffer child, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_tribe_management_topic(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_initial_setup(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer device, RustBuffer invite_code, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_fetch_msgs(RustBuffer seed, RustBuffer unique_time, RustBuffer state, uint64_t last_msg_idx, RustBuffer limit, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_handle(RustBuffer topic, RustBuffer payload, RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer my_alias, RustBuffer my_img, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_send(RustBuffer seed, RustBuffer unique_time, RustBuffer to, uint8_t msg_type, RustBuffer msg_json, RustBuffer state, RustBuffer my_alias, RustBuffer my_img, uint64_t amt_msat, int8_t is_tribe, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_keysend(RustBuffer seed, RustBuffer unique_time, RustBuffer to, RustBuffer state, uint64_t amt_msat, RustBuffer data, RustBuffer route_hint, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_pay(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer bolt11, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_make_media_token(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer host, RustBuffer muid, RustBuffer to, uint32_t expiry, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_make_media_token_with_meta(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer host, RustBuffer muid, RustBuffer to, uint32_t expiry, RustBuffer meta, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_make_media_token_with_price(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer host, RustBuffer muid, RustBuffer to, uint32_t expiry, uint64_t price, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_make_invoice(RustBuffer seed, RustBuffer unique_time, RustBuffer state, uint64_t amt_msat, RustBuffer description, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_pay_invoice(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer bolt11, RustBuffer overpay_msat, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_pay_contact_invoice(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer bolt11, RustBuffer my_alias, RustBuffer my_img, int8_t is_tribe, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_payment_hash_from_invoice(RustBuffer bolt11, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_parse_invoice(RustBuffer invoice_json, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_create_tribe(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer tribe_server_pubkey, RustBuffer tribe_json, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_join_tribe(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer tribe_pubkey, RustBuffer tribe_route_hint, RustBuffer alias, uint64_t amt_msat, int8_t is_private, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_list_tribe_members(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer tribe_server_pubkey, RustBuffer tribe_pubkey, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_make_invite(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer host, uint64_t amt_msat, RustBuffer my_alias, RustBuffer tribe_host, RustBuffer tribe_pubkey, RustBuffer inviter_pubkey, RustBuffer inviter_route_hint, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_process_invite(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer invite_qr, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_parse_invite(RustBuffer invite_qr, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_code_from_invite(RustBuffer invite_qr, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_cancel_invite(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer invite_code, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_default_tribe_server(RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_read(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer pubkey, uint64_t msg_idx, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_reads(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_mute(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer pubkey, uint8_t mute_level, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_mutes(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_set_push_token(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer push_token, RustBuffer push_key, RustCallStatus *_Nonnull out_status
);
uint64_t uniffi_sphinxrs_fn_func_decrypt_child_index(RustBuffer encrypted_child, RustBuffer push_key, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_msgs_counts(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_fetch_msgs_batch(RustBuffer seed, RustBuffer unique_time, RustBuffer state, uint64_t last_msg_idx, RustBuffer limit, RustBuffer reverse, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_fetch_msgs_batch_okkey(RustBuffer seed, RustBuffer unique_time, RustBuffer state, uint64_t last_msg_idx, RustBuffer limit, RustBuffer reverse, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_fetch_first_msgs_per_key(RustBuffer seed, RustBuffer unique_time, RustBuffer state, uint64_t last_msg_idx, RustBuffer limit, RustBuffer reverse, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_fetch_payments(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer since, RustBuffer limit, RustBuffer scid, RustBuffer remote_only, RustBuffer min_msat, RustBuffer reverse, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_get_tags(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer tags, RustBuffer pubkey, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_delete_msgs(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer pubkey, RustBuffer msg_idxs, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_update_tribe(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer tribe_server_pubkey, RustBuffer tribe_json, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_delete_tribe(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustBuffer tribe_server_pubkey, RustBuffer tribe_pubkey, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_add_node(RustBuffer node, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_concat_route(RustBuffer state, RustBuffer end_hops, RustBuffer router_pubkey, uint64_t amt_msat, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_ping_done(RustBuffer seed, RustBuffer unique_time, RustBuffer state, uint64_t ping_ts, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_fetch_pings(RustBuffer seed, RustBuffer unique_time, RustBuffer state, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_id_from_macaroon(RustBuffer macaroon, RustCallStatus *_Nonnull out_status
);
RustBuffer uniffi_sphinxrs_fn_func_find_route(RustBuffer state, RustBuffer to_pubkey, RustBuffer route_hint, uint64_t amt_msat, RustCallStatus *_Nonnull out_status
);
RustBuffer ffi_sphinxrs_rustbuffer_alloc(int32_t size, RustCallStatus *_Nonnull out_status
);
RustBuffer ffi_sphinxrs_rustbuffer_from_bytes(ForeignBytes bytes, RustCallStatus *_Nonnull out_status
);
void ffi_sphinxrs_rustbuffer_free(RustBuffer buf, RustCallStatus *_Nonnull out_status
);
RustBuffer ffi_sphinxrs_rustbuffer_reserve(RustBuffer buf, int32_t additional, RustCallStatus *_Nonnull out_status
);
uint16_t uniffi_sphinxrs_checksum_func_pubkey_from_secret_key(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_derive_shared_secret(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_encrypt(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_decrypt(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_node_keys(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_mnemonic_from_entropy(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_entropy_from_mnemonic(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_mnemonic_to_seed(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_entropy_to_seed(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_build_request(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_parse_response(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_make_auth_token(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_run(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_sha_256(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_create_onion(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_create_onion_msg(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_create_keysend(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_create_keysend_msg(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_peel_onion(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_peel_onion_msg(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_peel_payment(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_peel_payment_msg(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_sign_ms(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_signed_timestamp(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_sign_bytes(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_sign_base64(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_pubkey_from_seed(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_root_sign_ms(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_xpub_from_seed(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_set_network(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_set_device(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_set_blockheight(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_blockheight(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_add_contact(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_contact(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_list_contacts(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_contact_pubkey_by_child_index(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_contact_pubkey_by_encrypted_child(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_tribe_management_topic(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_initial_setup(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_fetch_msgs(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_handle(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_send(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_keysend(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_pay(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_make_media_token(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_make_media_token_with_meta(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_make_media_token_with_price(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_make_invoice(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_pay_invoice(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_pay_contact_invoice(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_payment_hash_from_invoice(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_parse_invoice(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_create_tribe(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_join_tribe(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_list_tribe_members(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_make_invite(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_process_invite(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_parse_invite(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_code_from_invite(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_cancel_invite(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_default_tribe_server(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_read(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_reads(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_mute(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_mutes(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_set_push_token(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_decrypt_child_index(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_msgs_counts(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_fetch_msgs_batch(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_fetch_msgs_batch_okkey(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_fetch_first_msgs_per_key(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_fetch_payments(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_get_tags(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_delete_msgs(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_update_tribe(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_delete_tribe(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_add_node(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_concat_route(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_ping_done(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_fetch_pings(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_id_from_macaroon(void
    
);
uint16_t uniffi_sphinxrs_checksum_func_find_route(void
    
);
uint32_t ffi_sphinxrs_uniffi_contract_version(void
    
);


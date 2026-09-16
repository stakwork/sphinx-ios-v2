#ifndef CRASH_SIGNAL_TRAMPOLINE_H
#define CRASH_SIGNAL_TRAMPOLINE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SPHX_DUMP_MAGIC "SPHXDUMP"
#define SPHX_DUMP_VERSION 1u
#define SPHX_MAX_DUMP_BYTES 65536u
#define SPHX_MAX_ADDRESSES 8u
#define SPHX_MAX_IMAGES 256u
#define SPHX_NAME_LEN 64u
#define SPHX_UUID_LEN 37u

/* Packed on-disk size: magic(8)+ver(4)+sig(4)+pc(8)+addrCount(4)+imgIdx(4)
 * +name(64)+uuid(37)+load(8)+size(8) = 149. */
#define SPHX_DUMP_SIZE 149u

/// Reset reentrancy guard, image table, and dump fd. Safe to call at install.
void sphx_crash_reset_state(void);

/// Takes ownership of `fd` (may be -1). Previous fd is closed if valid.
void sphx_crash_set_dump_fd(int fd);

void sphx_crash_clear_images(void);

/// Copies name/uuid into the preallocated table. Returns 0 on success, -1 if full.
int sphx_crash_add_image(
    const char *name,
    const char *uuid,
    uint64_t load_address,
    uint64_t size
);

uint32_t sphx_crash_image_count(void);

/// Installs SA_SIGINFO|SA_RESETHAND handlers for fatal signals. C-only entrypoint.
void sphx_crash_install_handlers(void);

/// Signal-safe dump of `sig` + interrupted `pc`. Returns 1 if written, 0 on failure.
int sphx_crash_write_interrupted_pc(int sig, uint64_t pc);

/// Returns 1 on first entry, 0 if already handling (nested/reentrant).
int sphx_crash_try_begin_handling(void);

int sphx_crash_is_handling(void);

/// Test helper: same entry logic as the real handler without re-raising.
/// Nested calls return 0 and do not write.
int sphx_crash_handle_signal_for_test(int sig, uint64_t pc);

#ifdef __cplusplus
}
#endif

#endif /* CRASH_SIGNAL_TRAMPOLINE_H */

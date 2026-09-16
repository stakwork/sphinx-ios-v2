#include "CrashSignalTrampoline.h"

#include <signal.h>
#include <string.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <sys/ucontext.h>
#endif

typedef struct {
    char name[SPHX_NAME_LEN];
    char uuid[SPHX_UUID_LEN];
    uint64_t load_address;
    uint64_t size;
} sphx_image_t;

static volatile sig_atomic_t g_handling = 0;
static int g_dump_fd = -1;
static sphx_image_t g_images[SPHX_MAX_IMAGES];
static uint32_t g_image_count = 0;

/* Packed on-disk dump. Little-endian. Magic is ASCII "SPHXDUMP". */
typedef struct __attribute__((packed)) {
    char magic[8];
    uint32_t version;
    int32_t signal;
    uint64_t pc;
    uint32_t address_count;
    uint32_t image_index; /* 0xFFFFFFFF if unknown */
    char image_name[SPHX_NAME_LEN];
    char image_uuid[SPHX_UUID_LEN];
    uint64_t load_address;
    uint64_t image_size;
} sphx_dump_t;

_Static_assert(sizeof(sphx_dump_t) == SPHX_DUMP_SIZE, "dump struct size mismatch");

void sphx_crash_reset_state(void) {
    g_handling = 0;
    if (g_dump_fd >= 0) {
        close(g_dump_fd);
        g_dump_fd = -1;
    }
    g_image_count = 0;
    memset(g_images, 0, sizeof(g_images));
}

void sphx_crash_set_dump_fd(int fd) {
    if (g_dump_fd >= 0 && g_dump_fd != fd) {
        close(g_dump_fd);
    }
    g_dump_fd = fd;
}

void sphx_crash_clear_images(void) {
    g_image_count = 0;
    memset(g_images, 0, sizeof(g_images));
}

int sphx_crash_add_image(
    const char *name,
    const char *uuid,
    uint64_t load_address,
    uint64_t size
) {
    if (g_image_count >= SPHX_MAX_IMAGES) {
        return -1;
    }
    sphx_image_t *img = &g_images[g_image_count];
    memset(img, 0, sizeof(*img));
    if (name) {
        strncpy(img->name, name, SPHX_NAME_LEN - 1);
    }
    if (uuid) {
        strncpy(img->uuid, uuid, SPHX_UUID_LEN - 1);
    }
    img->load_address = load_address;
    img->size = size;
    g_image_count += 1;
    return 0;
}

uint32_t sphx_crash_image_count(void) {
    return g_image_count;
}

int sphx_crash_is_handling(void) {
    return (int)g_handling;
}

int sphx_crash_try_begin_handling(void) {
    if (g_handling != 0) {
        return 0;
    }
    g_handling = 1;
    return 1;
}

static int sphx_find_image(uint64_t address, uint32_t *out_index) {
    uint32_t i;
    int found = 0;
    uint64_t best_load = 0;
    uint32_t best_index = 0;

    for (i = 0; i < g_image_count; i++) {
        uint64_t start = g_images[i].load_address;
        uint64_t size = g_images[i].size;
        if (size == 0) {
            continue;
        }
        if (address >= start && address < start + size) {
            if (!found || start >= best_load) {
                found = 1;
                best_load = start;
                best_index = i;
            }
        }
    }
    if (found) {
        *out_index = best_index;
        return 1;
    }
    return 0;
}

/* Async-signal-safe: only POSIX write/lseek + memcpy of preallocated state. */
int sphx_crash_write_interrupted_pc(int sig, uint64_t pc) {
    sphx_dump_t dump;
    uint32_t img_index = 0;
    ssize_t written;
    const uint32_t unknown = 0xFFFFFFFFu;

    if (g_dump_fd < 0) {
        return 0;
    }

    memset(&dump, 0, sizeof(dump));
    memcpy(dump.magic, SPHX_DUMP_MAGIC, 8);
    dump.version = SPHX_DUMP_VERSION;
    dump.signal = (int32_t)sig;
    dump.pc = pc;
    dump.address_count = 1;
    dump.image_index = unknown;
    dump.load_address = 0;
    dump.image_size = 0;

    if (sphx_find_image(pc, &img_index)) {
        dump.image_index = img_index;
        memcpy(dump.image_name, g_images[img_index].name, SPHX_NAME_LEN);
        memcpy(dump.image_uuid, g_images[img_index].uuid, SPHX_UUID_LEN);
        dump.load_address = g_images[img_index].load_address;
        dump.image_size = g_images[img_index].size;
    }

    if (lseek(g_dump_fd, 0, SEEK_SET) < 0) {
        return 0;
    }

    written = write(g_dump_fd, &dump, sizeof(dump));
    if (written != (ssize_t)sizeof(dump)) {
        return 0;
    }
    (void)fsync(g_dump_fd);
    return 1;
}

int sphx_crash_handle_signal_for_test(int sig, uint64_t pc) {
    if (!sphx_crash_try_begin_handling()) {
        return 0;
    }
    return sphx_crash_write_interrupted_pc(sig, pc);
}

static void sphx_restore_default_and_reraise(int sig) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_DFL;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(sig, &sa, NULL);
    raise(sig);
}

static uint64_t sphx_pc_from_ucontext(void *ucontext_ptr) {
    if (ucontext_ptr == NULL) {
        return 0;
    }
#if defined(__APPLE__)
    {
        ucontext_t *uc = (ucontext_t *)ucontext_ptr;
#if defined(__arm64__) || defined(__aarch64__)
        return (uint64_t)uc->uc_mcontext->__ss.__pc;
#elif defined(__x86_64__)
        return (uint64_t)uc->uc_mcontext->__ss.__rip;
#else
        return 0;
#endif
    }
#else
    (void)ucontext_ptr;
    return 0;
#endif
}

static void sphx_crash_sigaction(int sig, siginfo_t *info, void *ucontext) {
    (void)info;

    /* Nested/reentrant: restore default and re-raise without touching the dump. */
    if (!sphx_crash_try_begin_handling()) {
        sphx_restore_default_and_reraise(sig);
        return;
    }

    {
        uint64_t pc = sphx_pc_from_ucontext(ucontext);
        (void)sphx_crash_write_interrupted_pc(sig, pc);
    }

    sphx_restore_default_and_reraise(sig);
}

void sphx_crash_install_handlers(void) {
    struct sigaction sa;
    const int signals[] = { SIGSEGV, SIGABRT, SIGILL, SIGFPE, SIGBUS, SIGTRAP };
    size_t i;

    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = sphx_crash_sigaction;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;

    for (i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) {
        sigaction(signals[i], &sa, NULL);
    }
}

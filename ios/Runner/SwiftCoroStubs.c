#include <stdlib.h>

__attribute__((visibility("default")))
void *swift_coroFrameAlloc(size_t size) {
    return malloc(size);
}

__attribute__((visibility("default")))
void swift_coroFrameDealloc(void *ptr) {
    free(ptr);
}

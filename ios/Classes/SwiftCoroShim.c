#include <stdlib.h>
#include <stdint.h>

// Swift Concurrency Runtime compatibility stub for Swift 6.1+ static frameworks
__attribute__((visibility("default")))
__attribute__((weak))
void *swift_coroFrameAlloc(size_t size, uint64_t typeId) {
    if (size == 0) {
        size = 1;
    }
    return malloc(size);
}

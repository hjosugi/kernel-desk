/* Synthetic learning sample. This is not Linux kernel source code. */

#include <stdbool.h>
#include <stddef.h>

struct page_table_entry {
    unsigned long frame_number;
    bool present;
    bool writable;
};

struct address_space {
    struct page_table_entry *entries;
    size_t entry_count;
};

enum fault_result {
    FAULT_RESOLVED,
    FAULT_INVALID_ADDRESS,
    FAULT_PERMISSION_DENIED,
};

static struct page_table_entry *lookup_entry(
    struct address_space *space,
    unsigned long page_index
) {
    if (page_index >= space->entry_count) {
        return NULL;
    }

    return &space->entries[page_index];
}

enum fault_result handle_page_fault(
    struct address_space *space,
    unsigned long page_index,
    bool write_access
) {
    struct page_table_entry *entry = lookup_entry(space, page_index);

    if (entry == NULL) {
        return FAULT_INVALID_ADDRESS;
    }

    if (write_access && !entry->writable) {
        return FAULT_PERMISSION_DENIED;
    }

    if (!entry->present) {
        entry->frame_number = page_index + 1000;
        entry->present = true;
    }

    return FAULT_RESOLVED;
}

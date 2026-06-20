/* Synthetic learning sample. This is not Linux kernel source code. */

#include <stddef.h>

struct file;

typedef long (*read_operation)(
    struct file *file,
    char *buffer,
    size_t count,
    long *offset
);

struct file_operations {
    read_operation read;
};

struct file {
    const struct file_operations *operations;
    long offset;
    int readable;
};

long vfs_read(struct file *file, char *buffer, size_t count) {
    if (file == NULL || buffer == NULL || !file->readable) {
        return -1;
    }

    if (file->operations == NULL || file->operations->read == NULL) {
        return -2;
    }

    return file->operations->read(file, buffer, count, &file->offset);
}

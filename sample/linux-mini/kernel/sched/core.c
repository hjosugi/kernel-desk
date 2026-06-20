/* Synthetic learning sample. This is not Linux kernel source code. */

#include <stddef.h>

struct task {
    int id;
    int priority;
    int runnable;
};

struct run_queue {
    struct task *tasks;
    size_t length;
    size_t current_index;
};

static struct task *pick_next_task(struct run_queue *queue) {
    struct task *best = NULL;

    for (size_t index = 0; index < queue->length; index++) {
        struct task *candidate = &queue->tasks[index];

        if (!candidate->runnable) {
            continue;
        }

        if (best == NULL || candidate->priority > best->priority) {
            best = candidate;
            queue->current_index = index;
        }
    }

    return best;
}

static void context_switch(struct task *previous, struct task *next) {
    (void)previous;
    (void)next;
    /* A real kernel would save and restore architecture-specific state here. */
}

void schedule(struct run_queue *queue) {
    struct task *previous = &queue->tasks[queue->current_index];
    struct task *next = pick_next_task(queue);

    if (next != NULL && next != previous) {
        context_switch(previous, next);
    }
}

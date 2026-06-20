/* Synthetic learning sample. This is not Linux kernel source code. */

#include <stdbool.h>
#include <stdio.h>

static bool interrupts_enabled;

static void setup_architecture(void) {
    puts("prepare architecture-specific state");
}

static void initialize_memory(void) {
    puts("initialize physical and virtual memory");
}

static void initialize_scheduler(void) {
    puts("initialize run queues and the idle task");
}

static void enable_interrupts(void) {
    interrupts_enabled = true;
}

static void launch_first_process(void) {
    if (!interrupts_enabled) {
        puts("cannot launch userspace before interrupts are enabled");
        return;
    }

    puts("launch the first userspace process");
}

void start_kernel(void) {
    setup_architecture();
    initialize_memory();
    initialize_scheduler();
    enable_interrupts();
    launch_first_process();
}

int main(void) {
    start_kernel();
    return 0;
}

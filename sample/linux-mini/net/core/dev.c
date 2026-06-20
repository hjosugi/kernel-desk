/* Synthetic learning sample. This is not Linux kernel source code. */

#include <stddef.h>

struct packet {
    const unsigned char *data;
    size_t length;
};

struct network_device;

typedef int (*transmit_operation)(
    struct network_device *device,
    struct packet *packet
);

struct network_device {
    const char *name;
    int running;
    transmit_operation transmit;
};

int send_packet(struct network_device *device, struct packet *packet) {
    if (device == NULL || packet == NULL) {
        return -1;
    }

    if (!device->running || device->transmit == NULL) {
        return -2;
    }

    return device->transmit(device, packet);
}

void receive_packet(struct packet *packet) {
    if (packet == NULL || packet->length == 0) {
        return;
    }

    /* A real stack would classify the protocol and dispatch the packet. */
}

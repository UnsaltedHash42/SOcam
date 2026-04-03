#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;

    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    if (kr != KERN_SUCCESS) return 1;

    kr = mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    kr = bootstrap_register(bootstrap_port, "org.offsec.example", port);

    struct {
        mach_msg_header_t header;
        char some_text[10];
        int secret_number;
        mach_msg_trailer_t trailer;
    } msg;

    printf("Listening on org.offsec.example...\n");
    kr = mach_msg(&msg.header, MACH_RCV_MSG, 0, sizeof(msg), port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    msg.some_text[9] = 0; 
    printf("Received: %s | %d\n", msg.some_text, msg.secret_number);
    return 0;
}
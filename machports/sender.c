// sender.c (Fully Assembled)
#include <stdio.h>
#include <string.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;
    
    kr = bootstrap_look_up(bootstrap_port, "/System/Library/LaunchAgents/com.apple.tccd.plist", &port);
    if (kr != KERN_SUCCESS) return 1;

    struct {
        mach_msg_header_t header;
        char some_text[10];
        int secret_number;
    } msg;

    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    msg.header.msgh_remote_port = port;           
    msg.header.msgh_local_port = MACH_PORT_NULL;  
    
    strncpy(msg.some_text, "Hello", sizeof(msg.some_text));
    msg.secret_number = 35;

    kr = mach_msg(&msg.header, MACH_SEND_MSG, sizeof(msg), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    printf("Sent message.\n");
    return 0;
}
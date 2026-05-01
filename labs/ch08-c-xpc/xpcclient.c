/*
 * Minimal XPC client — lab ch08-c-xpc
 * Mach service must match plist / server: com.example.student.xpc
 */
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <xpc/xpc.h>

int main(void)
{
	xpc_object_t my_bool;
	xpc_object_t my_message;

	my_message = xpc_dictionary_create(NULL, NULL, 0);
	my_bool = xpc_bool_create(1);
	xpc_dictionary_set_value(my_message, "bool_name", my_bool);
	xpc_release(my_bool);

	xpc_connection_t conn =
	    xpc_connection_create_mach_service("com.example.student.xpc", NULL, 0);

	xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
		printf("generic handler: %s\n", xpc_copy_description(event));
	});

	xpc_connection_resume(conn);

	xpc_connection_send_message_with_reply(conn, my_message, NULL, ^(xpc_object_t resp) {
		    printf("reply object: %s\n", xpc_copy_description(resp));
		    const char *rep = xpc_dictionary_get_string(resp, "reply");
		    if (rep)
			    printf("reply string: %s\n", rep);
		    exit(0);
	    });

	xpc_release(my_message);

	dispatch_main();
	/* not reached */
	return 0;
}

/*
 * Minimal XPC listener (root Mach service) — lab ch08-c-xpc
 */
#include <stdio.h>
#include <stdlib.h>
#include <xpc/xpc.h>

static void my_peer_handler(xpc_connection_t connection, xpc_object_t event)
{
	(void)connection;
	xpc_type_t type = xpc_get_type(event);

	if (type == XPC_TYPE_DICTIONARY) {
		xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);
		xpc_object_t reply = xpc_dictionary_create_reply(event);
		xpc_dictionary_set_string(reply, "reply", "this is my reply");
		xpc_connection_send_message(remote, reply);
		xpc_release(reply);
	} else if (type == XPC_TYPE_ERROR) {
		fprintf(stderr, "peer error: %s\n", xpc_copy_description(event));
	}
}

static void my_connection_handler(xpc_connection_t connection)
{
	xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
		my_peer_handler(connection, event);
	});
	xpc_connection_resume(connection);
}

int main(void)
{
	xpc_connection_t service = xpc_connection_create_mach_service(
	    "com.example.student.xpc", NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER);

	xpc_connection_set_event_handler(service, ^(xpc_object_t event) {
		my_connection_handler((xpc_connection_t)event);
	});

	xpc_connection_resume(service);

	for (;;)
		sleep(86400);
	/* not reached */
	return 0;
}

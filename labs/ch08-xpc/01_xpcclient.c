/*
 * =============================================================================
 * 01_xpcclient.c — minimal libxpc *client* (Chapter 8 C API lab)
 * =============================================================================
 *
 * PURPOSE
 *   Connects to a Mach-registered XPC service (see xpcserver.c + plist) and
 *   sends one dictionary message with a reply handler. Students compare this
 *   flow to NSXPC in 02_nsxpc*.m and Swift in 06_* (same repo folder).
 *
 * BUILD
 *   clang -fblocks -o 01_xpcclient 01_xpcclient.c
 *
 * MACH NAME
 *   Must match 01_xpcserver.c and 01_com.example.student.xpc.plist.template.
 *
 * =============================================================================
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

	/*
	 * XPC messages crossing the boundary are almost always *dictionaries*.
	 * Keys are C strings; values are typed xpc_object_t (bool, int64, data, …).
	 */
	my_message = xpc_dictionary_create(NULL, NULL, 0);

	/* Create a standalone bool object, insert it, then release our reference
	 * because xpc_dictionary_set_value retains the value. */
	my_bool = xpc_bool_create(1);
	xpc_dictionary_set_value(my_message, "bool_name", my_bool);
	xpc_release(my_bool);

	/*
	 * Client side of a launchd-managed Mach service:
	 *   xpc_connection_create_mach_service(name, target_queue, flags)
	 * flags == 0 means “connect to existing service”, not “create listener”.
	 * Third argument LISTENER is used only in the server binary.
	 */
	xpc_connection_t conn =
	    xpc_connection_create_mach_service("com.example.student.xpc", NULL, 0);

	/*
	 * Mandatory event handler: receives connection-level events (errors,
	 * cancellation) and sometimes peer messages depending on setup.
	 * Here we just log with xpc_copy_description (debug aid).
	 */
	xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
		char *desc = xpc_copy_description(event);
		printf("connection event handler: %s\n", desc);
		free(desc);
	});

	/* Activates the connection; until resume, the connection is inactive. */
	xpc_connection_resume(conn);

	/*
	 * Async send with reply:
	 *   - my_message: the request dictionary
	 *   - NULL: default target queue for the reply handler (libdispatch)
	 *   - block: invoked when the reply dictionary arrives (or on error object)
	 */
	xpc_connection_send_message_with_reply(conn, my_message, NULL, ^(xpc_object_t resp) {
		char *desc = xpc_copy_description(resp);
		printf("reply object: %s\n", desc);
		free(desc);

		const char *rep = xpc_dictionary_get_string(resp, "reply");
		if (rep)
			printf("reply string: %s\n", rep);
		exit(0);
	});

	/* We no longer need our handle to the outbound message dictionary. */
	xpc_release(my_message);

	/*
	 * dispatch_main() never returns; it runs the main queue so reply blocks
	 * and connection events can fire. Without it, the program would exit
	 * before the async reply arrives.
	 */
	dispatch_main();

	return 0;
}

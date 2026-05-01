/*
 * =============================================================================
 * xpcserver.c — minimal libxpc *listener* + peer handler (Chapter 8 C API lab)
 * =============================================================================
 *
 * PURPOSE
 *   Registers as the Mach listener for `com.example.student.xpc` (via
 *   XPC_CONNECTION_MACH_SERVICE_LISTENER). launchd must own the receive right
 *   for that name in the plist’s MachServices dictionary.
 *
 * LAYERING (teaching model)
 *   1) Listener connection — accepts new peer connections (each becomes its
 *      own xpc_connection_t).
 *   2) Per-peer connection — receives dictionaries or XPC_TYPE_ERROR.
 *   3) Reply — xpc_dictionary_create_reply ties the reply to the inbound message.
 *
 * BUILD
 *   clang -fblocks -o xpcserver xpcserver.c
 *
 * =============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <xpc/xpc.h>

/*
 * Handles one *message event* on an already-accepted peer connection.
 * `event` is either XPC_TYPE_DICTIONARY (application payload) or
 * XPC_TYPE_ERROR (channel teardown, etc.).
 */
static void my_peer_handler(xpc_connection_t connection, xpc_object_t event)
{
	(void)connection; /* unused; remote end is taken from the dictionary */

	xpc_type_t type = xpc_get_type(event);

	if (type == XPC_TYPE_DICTIONARY) {
		/*
		 * For incoming request dictionaries, `xpc_dictionary_get_remote_connection`
		 * yields the peer connection used to send the *reply* back on.
		 */
		xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);

		/* Replies must be created from the original message to preserve XPC’s
		 * internal correlation / transaction metadata. */
		xpc_object_t reply = xpc_dictionary_create_reply(event);
		xpc_dictionary_set_string(reply, "reply", "this is my reply");
		xpc_connection_send_message(remote, reply);
		xpc_release(reply);
	} else if (type == XPC_TYPE_ERROR) {
		char *desc = xpc_copy_description(event);
		fprintf(stderr, "peer error: %s\n", desc);
		free(desc);
	}
}

/*
 * Called once per *new peer* that connects to our service. We install a second
 * event handler on that peer connection to demux messages vs errors.
 */
static void my_connection_handler(xpc_connection_t connection)
{
	xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
		my_peer_handler(connection, event);
	});
	xpc_connection_resume(connection);
}

int main(void)
{
	/*
	 * LISTENER mode: same API as the client, but the third flag tells libxpc
	 * this process is accepting inbound connections for the Mach service name.
	 * launchd must have advertised this name in a LaunchDaemon plist.
	 */
	xpc_connection_t service = xpc_connection_create_mach_service(
	    "com.example.student.xpc", NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER);

	/* First-level handler: `event` is actually another xpc_connection_t when
	 * a new client connects — cast and hand off to per-connection setup. */
	xpc_connection_set_event_handler(service, ^(xpc_object_t event) {
		my_connection_handler((xpc_connection_t)event);
	});

	xpc_connection_resume(service);

	/* Keep the daemon alive; launchd expects long-running services. */
	for (;;)
		sleep(86400);

	return 0;
}

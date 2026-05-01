/* Minimal NSXPC client — pairs with nsxpcserver.m + com.offsec.nsxpc plist. */
#include <Foundation/Foundation.h>

@protocol MyXPCProtocol
- (void)do_something:(NSString *)some_string withReply:(void (^)(unsigned int))reply;
@end

int main(void)
{
	@autoreleasepool {
		NSXPCConnection *my_connection = [[NSXPCConnection alloc]
		    initWithMachServiceName:@"com.offsec.nsxpc"
		                    options:NSXPCConnectionPrivileged];

		my_connection.remoteObjectInterface =
		    [NSXPCInterface interfaceWithProtocol:@protocol(MyXPCProtocol)];
		[my_connection resume];

		[[my_connection remoteObjectProxy]
		    do_something:@"hello"
		        withReply:^(unsigned int some_number) {
			        NSLog(@"Result was: %u", some_number);
		        }];

		sleep(10);
	}
	return 0;
}

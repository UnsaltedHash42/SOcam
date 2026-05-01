/* Minimal NSXPC listener — pairs with nsxpcclient.m + com.offsec.nsxpc plist. */
#include <Foundation/Foundation.h>

@protocol MyXPCProtocol
- (void)do_something:(NSString *)some_string withReply:(void (^)(unsigned int))reply;
@end

@interface MyXPCObject : NSObject <MyXPCProtocol>
@end

@implementation MyXPCObject
- (void)do_something:(NSString *)some_string withReply:(void (^)(unsigned int))reply
{
	(void)some_string;
	unsigned int response = 5;
	reply(response);
}
@end

@interface MyDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation MyDelegate
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
	(void)listener;
	newConnection.exportedInterface =
	    [NSXPCInterface interfaceWithProtocol:@protocol(MyXPCProtocol)];
	MyXPCObject *my_object = [MyXPCObject new];
	newConnection.exportedObject = my_object;
	[newConnection resume];
	return YES;
}
@end

int main(void)
{
	@autoreleasepool {
		NSXPCListener *listener =
		    [[NSXPCListener alloc] initWithMachServiceName:@"com.offsec.nsxpc"];
		id<NSXPCListenerDelegate> delegate = [MyDelegate new];
		listener.delegate = delegate;
		[listener resume];
		[[NSRunLoop currentRunLoop] run];
	}
	return 0;
}

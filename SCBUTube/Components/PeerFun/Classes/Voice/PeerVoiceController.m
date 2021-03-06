/**
 Copyright (c) 2011, Praveen K Jha, Praveen K Jha.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list
 of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or other
 materials provided with the distribution.
 Neither the name of the Praveen K Jha. nor the names of its contributors may be
 used to endorse or promote products derived from this software without specific
 prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE."
 **/
/**
 PeerVoiceController.h
 PeerFun
 Abstract: Controls the logic, controls, networking, and view of the actual game.
 Version: 1.0
 **/

#import "PeerVoiceController.h"
#import "ARAnnotations.h"
#import <GameKit/GKVoiceChatService.h>
#import <UIKit/UIImage.h>
#import "videoFrameManager.h"
#import "DownloadsViewController.h"

#include <ifaddrs.h>
#include <arpa/inet.h>

#define kWorldX 320.0
#define kWorldY 420.0
#define kBorder 10.0
#define kStartY kWorldY/3.0
#define kOffscreen 3.0
#define kTimestep 0.033

CGImageRef UIGetScreenImage();
//! Controls the logic, controls, networking, and view of the actual game.
@implementation PeerVoiceController
@synthesize stateLabel;
@synthesize arViewController;
@synthesize packetsEnum;

#pragma mark View Controller Methods

/** 
  The designated initializer.  Override if you create the controller
  programmatically and want to perform customization that is not appropriate
  for viewDidLoad.
**/
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil manager:(SessionManager *)aManager
{
    if (self == [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        manager = [aManager retain];
        [super setSessionManager:aManager];
        manager.gameDelegate = self;
        // Custom initialization
		_operationQueue = [[NSOperationQueue alloc] init];
		[_operationQueue setMaxConcurrentOperationCount:2];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = [manager displayNameForPeer:manager.currentConfPeerID];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(SessionDisconnectedByUser:)
												 name:@"SessionDisconnected"
											   object:nil];
	
    UIBarButtonItem *endButton = [[UIBarButtonItem alloc]
                                  initWithTitle:@"End Call"
                                  style:UIBarButtonItemStylePlain
                                  target:self
                                  action:@selector(endButtonHit)];
    self.navigationItem.leftBarButtonItem = endButton;
    [endButton release];
    
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc]
                                    initWithTitle:@"Share"
                                    style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(beginShare)];
    self.navigationItem.rightBarButtonItem = shareButton;
    [shareButton release];
    
    self.navigationItem.hidesBackButton = YES;
    circle.bounds.size = CGSizeMake(kSize,kSize);
    
    stateLabel.text = @"Connecting...";
#if TARGET_IPHONE_SIMULATOR
    UIBarButtonItem *btn=  self.navigationItem.rightBarButtonItem;
    [btn setEnabled:NO];
#endif
}

-(void) viewDidAppear:(BOOL)animated
{
    isMaster = NO;
    [super viewDidAppear:animated];
    UIBarButtonItem *btn1=  self.navigationItem.rightBarButtonItem;
#if !TARGET_IPHONE_SIMULATOR
    [btn1 setEnabled:YES];
#else
    [btn1 setEnabled:NO];
#endif
    [super rearView].hidden = NO;
    [super frontView].hidden =NO;
    [self grantMasterAccess:NO];
    _running = NO;
    [self sendArray:PacketTypeNSArray];
}

- (void)viewDidUnload
{
//    [collabView release];
//    collabView = nil;
    self.stateLabel = nil;
    [super viewDidUnload];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc 
{
    manager.gameDelegate = nil;
	[manager release];
    manager = nil;
//    [collabView release];
//    collabView = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Connection and Timer Logic

//! Update the call timer once a second.
- (void) updateElapsedTime:(NSTimer *) timer
{
	int hour, minute, second;
	NSTimeInterval elapsedTime = [NSDate timeIntervalSinceReferenceDate] - startTime;
	hour = elapsedTime / 3600;
	minute = (elapsedTime - hour * 3600) / 60;
	second = (elapsedTime - hour * 3600 - minute * 60);
	NSString *durationInCall = [NSString stringWithFormat:@"%2d:%02d:%02d", hour, minute, second];
    UIBarButtonItem *endButton=  self.navigationItem.leftBarButtonItem;
    if (endButton != nil)
    {
        [endButton setTitle:durationInCall];
    }
}

//! Called when the user hits the end call toolbar button.
-(void) endButtonHit
{
    [manager disconnectCurrentCall];
#if !TARGET_IPHONE_SIMULATOR
    [[super rearCamera].mySession stopRunning];
    [[super frontCamera].mySession stopRunning];
#endif
}

//! Grants master/screen share access if specified |toSelf| is YES
-(void)grantMasterAccess:(BOOL)toSelf
{
    if (toSelf)
    {
        isMaster = YES;
        [self sendPacket:PacketTypeMasterAccessAcquired];
        self.arViewController =[[[ARAnnotations alloc] init] initForView:super.rearView];
        [self openARScreen];
    }
    else
    {
        isMaster = NO;
        [self sendPacket:PacketTypeMasterAccessLeft];
    }
}

//! Begins sharing the screen with second party
-(void)beginShare
{
    [self grantMasterAccess:!isMaster];
}

//! Launches the sharing screen and starts streaming
- (void) openARScreen
{
	[self.navigationController pushViewController:self.arViewController animated:NO];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
    [self.arViewController release];
#if !TARGET_IPHONE_SIMULATOR
    [[super rearCamera].mySession stopRunning];
    [[super frontCamera].mySession stopRunning];
#endif
    [self startStreaming];
}

#pragma mark -
#pragma mark Streaming methods

//! starts streaming the image data to 2nd party
- (void)startStreaming
{
	_running = YES;
	[NSThread detachNewThreadSelector:@selector(threadedCaptureScreen) 
                             toTarget:self 
                           withObject:nil];
}

//! Begins screen capture on a separate thread
- (void)threadedCaptureScreen
{
	while (_running) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		[self captureScreen];	
		[pool release];
	}
}

//! Captures screen and puts the captured screen into a new operation queue
- (void)captureScreen
{	
	if (self.arViewController && [self.arViewController cameraController]) 
	{
		CGImageRef screen = UIGetScreenImage();
		UIImage* image = [UIImage imageWithCGImage:screen];
		CGImageRelease(screen);
		
		NSData *packetData = nil;
		
		if([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront])
			packetData =  UIImageJPEGRepresentation(image, 0.01f);
		else 
			packetData =  UIImageJPEGRepresentation(image, 0.02f);

		videoFrameManager *frameMgr = [[videoFrameManager alloc] initWithImageFrameBuffer:packetData 
																				  Manager:manager];
		[_operationQueue addOperation:frameMgr];
		[frameMgr release];
	}
	else
	{
		_running =NO;
		[manager disconnectCurrentCall];
	}
}

#pragma mark -
#pragma mark SessionManagerGameDelegate Methods

- (void) voiceChatWillStart:(SessionManager *)session
{
    stateLabel.text = @"Starting Voice Chat";
}

- (void) sendOSInfo 
{
  int outgoing =iPhone;
#if TARGET_IPHONE_SIMULATOR
            outgoing =Simulator;
#endif
            NSData *packet = [NSData dataWithBytes: &outgoing length: sizeof(outgoing)];
            [manager sendPacket:packet ofType:PacketTypeOSInfo];

}

- (void) session:(SessionManager *)session didConnectAsInitiator:(BOOL)shouldStart
{
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	
    stateLabel.text = @"Connected"; 
    
    // Schedule the game to update at 30fps and the call timer at 1fps.
	if (nil == callTimer) {
		callTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                    selector:@selector(updateElapsedTime:) userInfo:nil repeats:YES] retain];
        startTime = [NSDate timeIntervalSinceReferenceDate];
        
        // If the user is starting the voice chat, let the other party be the one
        // who starts the game.  That way both partys are starting at the same time.
        if (shouldStart) {
            if (packetsEnum == PacketTypeNSArray) {
            }
            [self sendPacket:PacketTypeStart];
            [self sendOSInfo];

            // The other party started the app and has connected.
            // Send the IP address and port information for video
            [self sendVideoURL];
        }
	}
}

-(void)SessionDisconnectedByUser:(NSNotification *)notification
{
	[self willDisconnect:manager];
}

//! If hit end call or the call failed or timed out, clear the state and go back a screen.
- (void) willDisconnect:(SessionManager *)session
{
	 _running =NO;
    stateLabel.text = @"Disconnected";
    partyTalking = FALSE;
    enemyTalking = FALSE;
    
    [callTimer invalidate];
	[callTimer release];
	callTimer = nil;
    
//    [collabView release];
//    collabView = nil;
#if !TARGET_IPHONE_SIMULATOR
    [[super rearCamera].mySession stopRunning];
    [[super frontCamera].mySession stopRunning];
#endif
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
	[self.navigationController popToRootViewControllerAnimated:YES];
//	self.arViewController =nil;
   
	if (self.arViewController)
	{
		ARViewController *vc = (ARViewController *)self.arViewController;
		if (vc && vc.cameraController)
		{
			[vc.cameraController dismissModalViewControllerAnimated:NO];
			vc.cameraController =nil;
		}
	}
   	manager.gameDelegate = nil;
	[manager release];
    manager = nil;
}

//! The GKSession got a packet and sent it to the game, so parse it and update state.
- (void) session:(SessionManager *)session 
didReceivePacket:(NSData*)data ofType:(PacketType)packetType
{
    Packet incoming;
    NSString *url;
    
    if ([data length] == sizeof(Packet)) {
        [data getBytes:&incoming length:sizeof(Packet)];
        
        switch (packetType) {
            case PacketTypeStart:
//                if (collabView == nil)
//                {
//                    // Create the graphics view
//                    CGRect	rect = CGRectMake(0.0, 0.0, kWorldX, kWorldY); 
//                    collabView = [[CollaborationView alloc] initWithFrame:rect];
//                    //[super.rearView addSubview:collabView];
//                    //[self.view addSubview:collabView];
//                    [collabView updateParty:circle.bounds];
//                }
                // The other party started the app and has connected.
                // Send the IP address and port information for video
                [self sendOSInfo];
                [self sendVideoURL];
                break;
            case PacketTypeCircle:
                // The other party has sent us a circle
                break;
            case PacketTypeText:
                // The other party sent some text
                break;
            case PacketTypeFreeHand:
                // The other party sent some free hand drawing
                break;
            case PacketTypeTalking:
                // The other party is speaking
                enemyTalking = YES;
//                circle.bounds.origin.y = CFConvertFloat32SwappedToHost(incoming.y[0]);
//                circle.bounds.origin.x = CFConvertFloat32SwappedToHost(incoming.x[0]);
//                [collabView updateParty:circle.bounds];
                break;
            case PacketTypeEndTalking:
                // The other party is ready to talk with someone again.
//                circle.bounds.origin.y = CFConvertFloat32SwappedToHost(incoming.y[0]);
//                circle.bounds.origin.x = CFConvertFloat32SwappedToHost(incoming.x[0]);
//                [collabView updateParty:circle.bounds];
                enemyTalking = NO;
                break;
            case PacketTypeMasterAccessAcquired:
                isMaster = NO;
                UIBarButtonItem *btn=  self.navigationItem.rightBarButtonItem;
                [btn setEnabled:NO];
#if !TARGET_IPHONE_SIMULATOR
                [[super rearCamera].mySession stopRunning];
#endif
                break;
            case PacketTypeMasterAccessLeft:
                isMaster = NO;
                _running = NO;
#if !TARGET_IPHONE_SIMULATOR
                 UIBarButtonItem *btn1=  self.navigationItem.rightBarButtonItem;
                 [btn1 setEnabled:YES];
                [[super frontCamera].mySession stopRunning];
                [[super rearCamera].mySession startRunning];
#endif
                break;
            case PacketTypeImage:
                //[super rearView].image = [UIImage imageWithData:incoming.image];
                break;
            default:
                break;
        }
    }
    else if (packetType == PacketTypeVideoURL)
    {
        // Hit the server with the url
        url = [[NSString alloc] initWithData:data
                                    encoding:NSASCIIStringEncoding];
        [[super webView] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
        [super rearView].hidden = NO;// Change to YES when you do it via browser
#if !TARGET_IPHONE_SIMULATOR
//        if([super frontCameraAvailable])
//        {
//            [[super rearCamera].mySession stopRunning];
//            [[super frontCamera].mySession startRunning];
//        }
//        else
//        {
//            [[super frontCamera].mySession stopRunning];
//            [[super rearCamera].mySession startRunning];
//        }
#endif
        [super webView].hidden = YES; // Change to NO when you do it via browser
        [url release];
    }
    else if (packetType ==PacketTypeImage)
    {
        [super rearView].image = [UIImage imageWithData:data];
    }
    else if (packetType ==PacketTypeOSInfo)
    {
        int ostype;
        [data getBytes: &ostype length: sizeof(ostype)];
        [super setIsSimulator:(ostype == Simulator)];
    }
    else if (packetType == PacketTypeNSArray){
        NSArray *datasArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSLog(@"dataArray: %@",datasArray);
        
        NSLog(@"data %@", data);

    }
}

//! Gets the IP address of the first available Wi-Fi network
- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    NSLog(@"IP address is :%@",address);
    return address;
}

//! Sends the video URL to the second party
- (void)sendVideoURL
{
    NSString *outgoing = [NSString stringWithFormat:@"http://%@:%@",[self getIPAddress],@"8080" ];
    NSData *packet = [outgoing dataUsingEncoding:NSASCIIStringEncoding];
    [manager sendPacket:packet ofType:PacketTypeVideoURL];
    //[packet release];
}

#pragma mark -
#pragma mark Network Logic

//! Send the same information each time, just with a different header
-(void) sendPacket:(PacketType)packetType
{
    Packet outgoing;
    outgoing.y[0] = CFConvertFloat32HostToSwapped(circle.bounds.origin.y);
    outgoing.x[0] = CFConvertFloat32HostToSwapped(circle.bounds.origin.x);
    NSData *packet = [[NSData alloc] initWithBytes:&outgoing length:sizeof(Packet)];
    [manager sendPacket:packet ofType:packetType];
    [packet release];
}

-(void) sendArray:(PacketType)packetType{    
    DownloadsViewController *downloadsVC = [[[DownloadsViewController alloc] init] autorelease];
    dataArray = downloadsVC.listDataArray;
    NSLog(@"dataArray: %@", downloadsVC.listDataArray);
    NSData *packet = [NSKeyedArchiver archivedDataWithRootObject:dataArray];
    [manager sendPacket:packet ofType:packetType];    
}


#pragma mark Game Control and Graphics Logic


// Allow parties to know that the parties are touching
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
//    partyTalking = YES;
//    CGPoint pt = [[touches anyObject] locationInView:collabView];
//    circle.bounds.origin.x = pt.x;
//    circle.bounds.origin.y = pt.y;
//    // Tell the graphics to update.
//    [collabView updateParty:circle.bounds];
//    [self sendPacket:PacketTypeTalking];
}

// Allow parties to know that the parties are touching
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
//    CGPoint pt = [[touches anyObject] locationInView:collabView];
//    circle.bounds.origin.x = pt.x;
//    circle.bounds.origin.y = pt.y;
//    // Tell the graphics to update.
//    [collabView updateParty:circle.bounds];
//    [self sendPacket:PacketTypeTalking];
}

// Allow parties to know that the parties are done touching
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
//    partyTalking = NO;
//    CGPoint pt = [[touches anyObject] locationInView:collabView];
//    circle.bounds.origin.x = pt.x;
//    circle.bounds.origin.y = pt.y;
//    // Tell the graphics to update.
//    [collabView updateParty:circle.bounds];
//    [self sendPacket:PacketTypeEndTalking];
}

// Same as touchesEnded.
-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

@end

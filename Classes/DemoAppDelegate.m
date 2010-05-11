//
//  DemoAppDelegate.m
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-10.
//  Copyright TropicalPixels. 2010. All rights reserved.
//

#import "DemoAppDelegate.h"
#import "DemoViewController.h"
#import <RTFKit/RTFKit.h>

@implementation DemoAppDelegate

@synthesize window;
@synthesize viewController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after app launch    
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"rtf"];  
	[[RKReader alloc] initWithFilePath:filePath];
	
	// Add the split view controller's view to the window and display.
   [window addSubview:viewController.view];
   [window makeKeyAndVisible];
	
	return YES;
}


- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end

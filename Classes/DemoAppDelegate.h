//
//  DemoAppDelegate.h
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-10.
//  Copyright TropicalPixels. 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DemoViewController;

@interface DemoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    DemoViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet DemoViewController *viewController;

@end


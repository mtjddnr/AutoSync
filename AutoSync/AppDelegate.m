//
//  AppDelegate.m
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate {
    NSStatusItem *_theItem;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self activateStatusMenu];
    
    [[NSUserDefaults standardUserDefaults] ]
}

- (void)activateStatusMenu {
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    _theItem = [bar statusItemWithLength:NSVariableStatusItemLength];
    
    [_theItem setTitle:NSLocalizedString(@"AutoSync",@"")];
    [_theItem setHighlightMode:YES];
    [_theItem setMenu:self.menu];
}

- (IBAction)onQuit:(id)sender {
    exit(0);
}
@end

//
//  BridgingHeader.h
//  Turncast (iOS)
//
//  Created by Harry Shamansky on 2/15/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

#if HOME_USE

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface HSSPrivateInterface
- (void)requestRemoteViewController;
@end

@interface MPMediaPickerController (Private)
- (id)loader;
+ (void)preheatMediaPicker;
@end

#endif

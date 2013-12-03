//
//  SEDoubanAuthorizeView.h
//  SocialEngine
//
//  Created by Peter Gu on 11/27/13.
//  Copyright (c) 2013 Alvin Zeng. All rights reserved.
//

#import "SEViewController.h"
#import "SEConfiguration.h"
#import "SESocialAccountEntity.h"

@protocol SEDoubanDelegate<NSObject>

- (void)authSuccess:(NSDictionary *)dic;

@end

@interface SEDoubanAuthorizeView : UIView

@property (strong, nonatomic) NSURL *requestURL;
@property (weak, nonatomic) id<SEDoubanDelegate> delegate;

- (id)initWithUrl:(NSURL *)aURL del:(id<SEDoubanDelegate>)del;
- (void)show;

@end

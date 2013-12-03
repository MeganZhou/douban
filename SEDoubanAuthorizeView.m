//
//  SEDoubanAuthorizeView.m
//  SocialEngine
//
//  Created by Peter Gu on 11/27/13.
//  Copyright (c) 2013 Alvin Zeng. All rights reserved.
//

#import "SEDoubanAuthorizeView.h"
#import <UIKit/UIKit.h>
#import <UIKit/UIDevice.h>

@interface NSString (ParseCategory)
- (NSMutableDictionary *)explodeToDictionaryInnerGlue:(NSString *)innerGlue
                                           outterGlue:(NSString *)outterGlue;
@end

@implementation NSString (ParseCategory)

- (NSMutableDictionary *)explodeToDictionaryInnerGlue:(NSString *)innerGlue
                                           outterGlue:(NSString *)outterGlue {
    // Explode based on outter glue
    NSArray *firstExplode = [self componentsSeparatedByString:outterGlue];
    NSArray *secondExplode;
    
    // Explode based on inner glue
    NSInteger count = [firstExplode count];
    NSMutableDictionary* returnDictionary = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        secondExplode =
        [(NSString*)[firstExplode objectAtIndex:i] componentsSeparatedByString:innerGlue];
        if ([secondExplode count] == 2) {
            [returnDictionary setObject:[secondExplode objectAtIndex:1]
                                 forKey:[secondExplode objectAtIndex:0]];
        }
    }
    return returnDictionary;
}

@end

@interface SEDoubanAuthorizeView ()<UIWebViewDelegate, NSURLConnectionDelegate>
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) UIActivityIndicatorView *indicatorView;

- (void)getRequestTokenAndExpiredTimeByAuthorizationCode:(NSString *)code;
- (NSString *)stringFromDictionaryData:(NSDictionary *)parameters;
- (NSString *)encodeString:(NSString *)stringValue;

@end

@implementation SEDoubanAuthorizeView

- (id)initWithUrl:(NSURL *)aURL del:(id<SEDoubanDelegate>)del
{
    _delegate = del;
    CGRect frame = CGRectMake(0.0, 20.0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - 20.0);
    
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0.5];
        _requestURL = aURL;
        _webView = [[UIWebView alloc] initWithFrame:CGRectMake(13.0, 13.0, self.frame.size.width - 26.0, self.frame.size.height - 26.0)];
        _webView.delegate = self;
        _webView.scalesPageToFit = YES;

        [self addSubview:_webView];
        [self addSubview:[self cancelButton]];
        [self addSubview:[self indicatorView]];
    }
    
    return self;
}

- (UIButton *)cancelButton
{
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.frame = CGRectMake(4.0, 4.0, 24.0, 24.0);
    [cancelButton setImage:[UIImage imageNamed:@"close.png"] forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(onCancelClick) forControlEvents:UIControlEventTouchUpInside];
    
    return cancelButton;
}

-(void)onCancelClick
{
    [_delegate authSuccess:nil];
    [self hideAuthorizeView:nil];
}
- (UIActivityIndicatorView *)indicatorView
{
    _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                     UIActivityIndicatorViewStyleGray];
    _indicatorView.autoresizingMask =
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
    | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    return _indicatorView;
}

- (void)hideAuthorizeView:(id)sender
{
    [_webView stopLoading];
    [self removeFromSuperview];
}

- (void)loadRequestURL
{
    NSURLRequest *request = [NSURLRequest requestWithURL:_requestURL];
    [_webView loadRequest:request];
}

- (void)show
{
    [self loadRequestURL];
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    
    [_indicatorView sizeToFit];
    [_indicatorView startAnimating];
    _indicatorView.center = _webView.center;
    
    [window addSubview:self];
    
    self.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.001, 0.001);
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3/1.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(bounce1AnimationStopped)];
    self.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.1, 1.1);
    [UIView commitAnimations];
}

- (void)bounce1AnimationStopped {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3/2];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(bounce2AnimationStopped)];
    self.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.9, 0.9);
    [UIView commitAnimations];
}

- (void)bounce2AnimationStopped {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3/2];
    self.transform = CGAffineTransformIdentity;
    [UIView commitAnimations];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [_delegate authSuccess:nil];
    [self hideAuthorizeView:webView];
}

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {
    
    NSURL *urlObj =  [request URL];
    NSString *url = [urlObj absoluteString];
    
    
    if ([url hasPrefix:SECONFIG(doubanCallbackUrl)]) {
        
        NSString* query = [urlObj query];
        NSMutableDictionary *parsedQuery = [query explodeToDictionaryInnerGlue:@"="
                                                                    outterGlue:@"&"];
        
        //access_denied
        NSString *error = [parsedQuery objectForKey:@"error"];
        if (error) {
            return NO;
        }
        
        //access_accept
        NSString *code = [parsedQuery objectForKey:@"code"];
        [self getRequestTokenAndExpiredTimeByAuthorizationCode:code];
        return NO;
    }
    
    [_indicatorView stopAnimating];
    
    return YES;
}

- (void)getRequestTokenAndExpiredTimeByAuthorizationCode:(NSString *)code
{
    //https://www.douban.com/service/auth2/token?
    //    client_id=0b5405e19c58e4cc21fc11a4d50aae64&
    //    client_secret=edfc4e395ef93375&
    //    redirect_uri=https://www.example.com/back&
    //    grant_type=authorization_code&
    //    code=9b73a4248
    NSString *urlString = [NSString stringWithFormat:@"https://www.douban.com/service/auth2/token"];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    //第二步，创建请求
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    
    [request setHTTPMethod:@"POST"];
    NSDictionary *postBody = [NSDictionary dictionaryWithObjectsAndKeys:SECONFIG(doubanClientId), @"client_id", SECONFIG(doubanConsumerSecret), @"client_secret", SECONFIG(doubanCallbackUrl), @"redirect_uri", @"authorization_code", @"grant_type", code ,@"code", nil];
    //    NSData *data = [NSJSONSerialization dataWithJSONObject:postBody options:NSJSONWritingPrettyPrinted error:nil];
    NSData *bodyData = [[self stringFromDictionaryData:postBody]dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:bodyData];
    
    
    //第三步，连接服务器
    
    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
    [connection start];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSDictionary *dataDictory = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    [_delegate authSuccess:dataDictory];
    
    [self removeFromSuperview];
//    [self dismissViewControllerAnimated:NO completion:nil];
}

- (NSString *)stringFromDictionaryData:(NSDictionary *)parameters
{
    NSString *tmpString = @"";
    if (parameters) {
        NSString *conjunction = @"";
        for (NSString *aKey in parameters) {
            id aValue = [parameters objectForKey:aKey];
            if ([aValue isKindOfClass:[NSArray class]]) {
                NSString *arrayKey = [aKey stringByAppendingString:@"[]"];
                if ([aKey isEqualToString:@"beforeImg"] || [aKey isEqualToString:@"afterImg"]) {
                    arrayKey = [arrayKey stringByAppendingString:@"[url]"];
                }
                for (NSString *arrayString in aValue) {
                    NSString *percentEscapeValue = [self encodeString:arrayString];
                    tmpString = [tmpString stringByAppendingString:[NSString stringWithFormat:@"%@%@=%@",conjunction, arrayKey, percentEscapeValue]];
                    conjunction = @"&";
                }
            } else {
                if ([aValue isKindOfClass:[NSNumber class]]) {
                    aValue = [aValue stringValue];
                }
                NSString *percentEscapeValue = [self encodeString:(NSString *)aValue];
                tmpString = [tmpString stringByAppendingString:[NSString stringWithFormat:@"%@%@=%@",conjunction, aKey, percentEscapeValue]];
                conjunction = @"&";
            }
        }
    }
    return tmpString;
}

- (NSString *)encodeString:(NSString *)stringValue
{
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(nil,
                                                                     (CFStringRef)stringValue,
                                                                     nil,
                                                                     (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                     kCFStringEncodingUTF8));
}


//- (void)cancelLogin:(id)sender
//{
//    [self dismissViewControllerAnimated:YES completion:nil];
//}

@end

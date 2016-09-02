//
//  CDOAuth1Helper.h
//  Pods
//
//  Created by Christopher de Haan on 9/1/16.
//
//  Copyright (c) 2016 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>

@interface CDOAuth1Helper : NSObject

/**
 *  ---------------------------------------------------------------------------------------
 * @name Authorization Callback
 *  ---------------------------------------------------------------------------------------
 */
#pragma mark - Authorization Callback

/**
 *  Check if an authorization callback opened the application.
 *
 *  @param url                  URL that opened the application.
 *  @param callbackURLScheme    URL scheme for oauth_callback.
 *  @param callbackURLHost      URL host for oauth_callback.
 *
 *  @return Whether or not a successful authorization callback URL was recieved.
 */
- (BOOL)isAuthorizationCallbackURL:(NSURL *)url
                 callbackURLScheme:(NSString *)callbackURLScheme
                   callbackURLHost:(NSString *)callbackURLHost;

@end

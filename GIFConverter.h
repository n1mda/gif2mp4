//
//  GIFToVideo.h
//
//  Created by Axel Möller on 16/01/14.
//  Copyright (c) 2014 Appreviation AB. All rights reserved.
//
//  This code is distributed under the terms and conditions of the MIT license.
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
#import <AVFoundation/AVFoundation.h>
#import <dispatch/dispatch.h>

dispatch_queue_t backgroundQueue;

@interface GIFConverter: NSObject

@property (strong, nonatomic) AVAssetWriter *videoWriter;

/**
 Convert a .GIF to .MP4 video file
 
 @param gif GIF image loaded into an NSData structure, eg.
            [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://i.imgur.com/xqG0QP3.gif"]];
 @param speed Speed of output video, where 1.0 is actual speed, 2.0 is double speed
 @param size The wanted size of the output file, will keep aspect and fill rest with black. Use CGSizeMake(0, 0) if you want to keep original size
 @param repeat Number of times to repeat GIF, 0 = play once, do not repeat
 @param output Path to output file, must not exist
 @param completion Block to call on completion, contains error if any
 */
- (void)convertGIFToMP4:(NSData *)gif speed:(float)speed size:(CGSize)size repeat:(int)repeat output:(NSString *)path completion:(void (^)(NSError *))completion;

@end

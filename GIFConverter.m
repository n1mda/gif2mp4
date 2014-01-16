//
//  GIFConverter.m
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

#import "GIFConverter.h"
#import <ImageIO/ImageIO.h>

@implementation GIFConverter

- (void)convertGIFToMP4:(NSData *)gif speed:(float)speed output:(NSString *)path completion:(void (^)(NSError *))completion {
    if(speed == 0.0)
        speed = 1.0; // You can't have 0 speed stupid
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:path]) {
        completion([[NSError alloc] initWithDomain:@"com.appreviation.gifconverter" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Output file already exists"}]);
        return;
    }
    
    NSDictionary *gifData = [self loadGIFData:gif];
    
    UIImage *first = [[gifData objectForKey:@"frames"] objectAtIndex:0];
    CGSize frameSize = first.size;
    frameSize.width = round(frameSize.width / 16) * 16;
    frameSize.height = round(frameSize.height / 16) * 16;
    
    NSError *error = nil;
    self.videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path] fileType:AVFileTypeQuickTimeMovie error:&error];
    
    if(error)
        NSLog(@"Error creating AVAssetWriter: %@", error.localizedDescription);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:frameSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:frameSize.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    [attributes setObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithUnsignedInt:frameSize.width] forKey:(NSString *)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithUnsignedInt:frameSize.height] forKey:(NSString *)kCVPixelBufferHeightKey];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:attributes];
    
    [self.videoWriter addInput:writerInput];
    
    writerInput.expectsMediaDataInRealTime = YES;
    
    [self.videoWriter startWriting];
    [self.videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    buffer = [self pixelBufferFromCGImage:[first CGImage] size:frameSize];
    BOOL result = [adaptor appendPixelBuffer:buffer withPresentationTime:kCMTimeZero];
    if(result == NO)
        NSLog(@"Failed to append buffer");
    
    if(buffer)
        CVBufferRelease(buffer);
        
    int fps = ([[gifData objectForKey:@"frames"] count] / [[gifData valueForKey:@"animationTime"] intValue]) * speed;
    NSLog(@"FPS: %d", fps);
    
    int i = 0;
    for(UIImage *image in [gifData objectForKey:@"frames"]) {
        if(adaptor.assetWriterInput.readyForMoreMediaData) {
            i++;
            CMTime frameTime = CMTimeMake(1, fps);
            CMTime lastTime = CMTimeMake(i, fps);
            CMTime presentTime = CMTimeAdd(lastTime, frameTime);
            
            buffer = [self pixelBufferFromCGImage:[image CGImage] size:frameSize];
            BOOL result = [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
            if(result == NO)
                NSLog(@"Failed to append buffer: %@", [self.videoWriter error]);
            
            if(buffer)
                CVBufferRelease(buffer);
            
        } else {
            NSLog(@"Error: Adaptor is not ready");
            i--;
        }
    }
    
    [writerInput markAsFinished];
    [self.videoWriter finishWritingWithCompletionHandler:^(void){
        NSLog(@"Finished writing");
        CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
        self.videoWriter = nil;
        completion(nil);
    }];
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size {
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pxbuffer);
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, 4*size.width, rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

- (NSDictionary *)loadGIFData:(NSData *)data {
    NSMutableArray *frames = nil;
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGFloat animationTime = 0.f;
    if(src) {
        size_t l = CGImageSourceGetCount(src);
        frames = [NSMutableArray arrayWithCapacity:l];
        for(size_t i = 0; i < l; i++) {
            CGImageRef img = CGImageSourceCreateImageAtIndex(src, i, NULL);
            NSDictionary *properties = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, i, NULL);
            NSDictionary *frameProperties = [properties objectForKey:(NSString *)kCGImagePropertyGIFDictionary];
            NSNumber *delayTime = [frameProperties objectForKey:(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
            animationTime += [delayTime floatValue];
            if(img) {
                [frames addObject:[UIImage imageWithCGImage:img]];
                CGImageRelease(img);
            }
        }
        CFRelease(src);
    }
    
    return @{@"animationTime" : [NSNumber numberWithFloat:animationTime], @"frames":  frames};
}


@end

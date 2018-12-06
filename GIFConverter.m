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

- (id)init {
    self = [super init];
    if(self) {
        backgroundQueue = dispatch_queue_create("com.convert.gif", NULL);
    }
    return self;
}

- (void)convertGIFToMP4:(NSData *)gif speed:(float)speed size:(CGSize)size repeat:(int)repeat output:(NSString *)path completion:(void (^)(NSError *))completion {
    
    repeat++;
    __block float movie_speed = speed;
    
    dispatch_async(backgroundQueue, ^(void){
        if(movie_speed == 0.0)
            movie_speed = 1.0; // You can't have 0 speed stupid
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if([fileManager fileExistsAtPath:path]) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completion([[NSError alloc] initWithDomain:@"com.appreviation.gifconverter" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Output file already exists"}]);
            });
            return;
        }
        
        NSDictionary *gifData = [self loadGIFData:gif resize:size repeat:repeat];
        
        UIImage *first = [[gifData objectForKey:@"frames"] objectAtIndex:0];
        CGSize frameSize = first.size;
        frameSize.width = round(frameSize.width / 16) * 16;
        frameSize.height = round(frameSize.height / 16) * 16;
        
        NSError *error = nil;
        self.videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path] fileType:AVFileTypeMPEG4 error:&error];
        
        if(error) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completion(error);
            });
            return;
        }
        
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
        int fps = ([[gifData objectForKey:@"frames"] count] / [[gifData valueForKey:@"animationTime"] floatValue]) * movie_speed;
        NSLog(@"FPS: %d", fps);
        buffer = [self pixelBufferFromCGImage:[first CGImage] size:frameSize];
        BOOL result = [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(0, fps)];
        if(result == NO)
            NSLog(@"Failed to append buffer");
        
        if(buffer)
            CVBufferRelease(buffer);
        
        int i = 0;
        while(i < [[gifData objectForKey:@"frames"] count]-1) {
            
            if(adaptor.assetWriterInput.readyForMoreMediaData) {
                i++;
                UIImage *image = [[gifData objectForKey:@"frames"] objectAtIndex:i];
                CMTime frameTime = CMTimeMake(0, fps);
                CMTime lastTime = CMTimeMake(i, fps);
                CMTime presentTime = CMTimeAdd(lastTime, frameTime);
                
                buffer = [self pixelBufferFromCGImage:[image CGImage] size:frameSize];
                
                BOOL result = [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                if(result == NO)
                    NSLog(@"Failed to append buffer: %@", [self.videoWriter error]);
                
                if(buffer)
                    CVBufferRelease(buffer);
                
                [NSThread sleepForTimeInterval:0.1];
                
            } else {
                NSLog(@"Error: Adaptor is not ready");
                [NSThread sleepForTimeInterval:0.1];
                i--;
            }
        }
        
        [writerInput markAsFinished];
        [self.videoWriter finishWritingWithCompletionHandler:^(void){
            NSLog(@"Finished writing");
            CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
            self.videoWriter = nil;
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completion(nil);
            });
        }];
    });
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

- (NSDictionary *)loadGIFData:(NSData *)data resize:(CGSize)size repeat:(int)repeat {
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
                if(size.width != 0.0 && size.height != 0.0) {
                    UIGraphicsBeginImageContext(size);
                    CGFloat width = CGImageGetWidth(img);
                    CGFloat height = CGImageGetHeight(img);
                    int x = 0, y = 0;
                    if(height > width) {
                        CGFloat padding = size.height / height; height = height * padding; width = width * padding; x = (size.width/2) - (width/2); y = 0;
                    } else if(width > height) {
                        CGFloat padding = size.width / width; height = height * padding; width = width * padding; x = 0; y = (size.height/2) - (height/2);
                    } else {
                        width = size.width; height = size.height;
                    }
                    
                    [[UIImage imageWithCGImage:img] drawInRect:CGRectMake(x, y, width, height) blendMode:kCGBlendModeNormal alpha:1.0];
                    [frames addObject:UIGraphicsGetImageFromCurrentImageContext()];
                    UIGraphicsEndImageContext();
                    CGImageRelease(img);

                } else {
                    [frames addObject:[UIImage imageWithCGImage:img]];
                    CGImageRelease(img);
                }
            }
        }
        CFRelease(src);
    }
    
    NSArray *framesCopy = [frames copy];
    for(int i = 1; i < repeat; i++) {
        [frames addObjectsFromArray:framesCopy];
    }
    
    return @{@"animationTime" : [NSNumber numberWithFloat:animationTime * repeat], @"frames":  frames};
}

@end

gif2mp4
=======

(Objective-C) Convert .GIF to .MP4

# Usage:

```objective-c
#import "GIFConverter.h"

NSData *gif = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://i.imgur.com/xqG0QP3.gif"]];
NSString *outputPath = [NSTemporaryDirectory() stringByAppendingString:@"output.mp4"];

GIFConverter *gifConverter = [[GIFConverter alloc] init];
[gifConverter convertGIFToMP4:gif speed:1.0 output:outputPath completion:^(NSError *error){
	if(!error)
		NSLog(@"Converted video!");
}];
```
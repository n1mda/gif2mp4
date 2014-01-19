gif2mp4
=======

(Objective-C) Convert .GIF to .MP4

MP4 videos must be of a height and width that is a multiple of 16, therefore what you enter as size may not be what comes out in the other end

# Usage:

```objective-c
#import "GIFConverter.h"

NSData *gif = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://i.imgur.com/xqG0QP3.gif"]];
NSString *outputPath = [NSTemporaryDirectory() stringByAppendingString:@"output.mp4"];

GIFConverter *gifConverter = [[GIFConverter alloc] init];
[gifConverter convertGIFToMP4:gif speed:1.0 size:CGSizeMake(200, 200) repeat:0 output:outputPath completion:^(NSError *error){
	if(!error)
		NSLog(@"Converted video!");
}];
```
//
//  ViewController.m
//  AFN-Learning
//
//  Created by PSBC on 2019/1/18.
//  Copyright © 2019 PSBC. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self test_rangeOfComposedCharacterSequencesForRange];

}


#pragma mark - 测试rangeOfComposedCharacterSequencesForRange方法使用
- (void)test_rangeOfComposedCharacterSequencesForRange {
    
    NSString *string = @"👴🏻👮🏽";
    static NSUInteger const batchSize = 5; // 针对string字符串，如果直接截取至7这个位置的话可能会导致截取字符不完整情况

    NSString *substr1 = [string substringToIndex:batchSize]; // 👴🏻,截断了，没有后面一个
    
    NSRange range = NSMakeRange(0, batchSize);
    range = [string rangeOfComposedCharacterSequencesForRange:range];
    NSString *substr2 = [string substringWithRange:range]; //👴🏻👮🏽，截取完整，超出一个位也相当于整个截取
    
    NSLog(@"%@ - %@",substr1, substr2);
}


#pragma mark - 查看 URLQueryAllowedCharacterSet 中的字符包括哪些，截取后结果是什么
- (void)test_URLQueryAllowedCharacterSet {
    NSCharacterSet *set = [NSCharacterSet URLQueryAllowedCharacterSet];
    // !$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~
    NSLog(@"%@",[self stringFromCharacterSet:set]);
    
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
    // -./0123456789?ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~
    NSLog(@"%@",[self stringFromCharacterSet:allowedCharacterSet]);
}

- (NSString *)stringFromCharacterSet:(NSCharacterSet *)charset {
    NSMutableArray *array = [NSMutableArray array];
    for (int plane = 0; plane <= 16; plane++) {
        if ([charset hasMemberInPlane:plane]) {
            UTF32Char c;
            for (c = plane << 16; c < (plane+1) << 16; c++) {
                if ([charset longCharacterIsMember:c]) {
                    UTF32Char c1 = OSSwapHostToLittleInt32(c); // To make it byte-order safe
                    NSString *s = [[NSString alloc] initWithBytes:&c1 length:4 encoding:NSUTF32LittleEndianStringEncoding];
                    [array addObject:s];
                }
            }
        }
    }
    return [array componentsJoinedByString:@""];
}


@end

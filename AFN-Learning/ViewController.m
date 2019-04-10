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
    
//    [self test_rangeOfComposedCharacterSequencesForRange];
    
    // 测试 NSURL 的 URLByAppendingPathComponent 方法
    [self test_URLByAppendingPathComponent];

}


- (void)test_URLByAppendingPathComponent {
    NSString *urlStr = @"http://www.baidu.com/index.html"; // 执行 URLByAppendingPathComponent 处理后 是 http://www.baidu.com/index.html/
//    NSString *urlStr = @"http://www.baidu.com"; // 不会执行 URLByAppendingPathComponent，以为 path 为 [url path] 为 nil
//    NSString *urlStr = @"http://www.baidu.com/"; // 也不会执行 URLByAppendingPathComponent 因为 有 / 这个结尾
    NSURL *url = [NSURL URLWithString:urlStr];
    
    //  注意 URL 为 http://www.example.com/index.html 时, 它的 path 是 '/index.html'
    
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
        /*
         URLByAppendingPathComponent 方法作用:
         如果原始URL不是以正斜杠结尾，而PathComponent不是以正斜杠开头，则会在返回的URL的两个部分之间插入正斜杠，除非原始URL是空字符串。
         如果接收器是一个文件URL，而路径组件没有以尾随斜杠结尾，则此方法可以读取文件元数据以确定结果路径是否为目录。这是同步进行的，如果接收器位于网络上安装的文件系统上，则可能会产生巨大的性能成本。如果知道结果路径是否为目录，则可以调用urlbyappendingpathcomponent:is directory:method以避免此文件元数据操作。
         */
    }
    NSLog(@"处理后的url - %@",url);
    // [NSURL +URLWithString:relativeToURL](https://www.jianshu.com/p/68b6e0ceabc8)，baseURL没有以“/”结尾的情况导致方法 ++URLWithString:relativeToURL 不正常执行的情况举例
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

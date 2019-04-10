//
//  NSDictionary+URL.h
//  AFN-Learning
//
//  Created by PSBC on 2019/1/21.
//  Copyright © 2019 PSBC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (URL)

/**
 从进行了百分号编码的URL QueryString 中复原传入的参数字典
 
 @param queryString 进行了百分号编码的URL QueryString
 @return 复原参数字典
 */
+ (NSDictionary *)dictionaryWithQueryString:(NSString *)queryString;

@end

NS_ASSUME_NONNULL_END

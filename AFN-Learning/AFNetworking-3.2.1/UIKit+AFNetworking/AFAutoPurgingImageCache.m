// AFAutoPurgingImageCache.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV 

#import "AFAutoPurgingImageCache.h"

@interface AFCachedImage : NSObject

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *identifier;         //url标识
@property (nonatomic, assign) UInt64 totalBytes;            //总大小
@property (nonatomic, strong) NSDate *lastAccessDate;       //上次获取时间
@property (nonatomic, assign) UInt64 currentMemoryUsage;    //这个参数没被用到过

@end

@implementation AFCachedImage

-(instancetype)initWithImage:(UIImage *)image identifier:(NSString *)identifier {
    if (self = [self init]) {
        self.image = image;
        self.identifier = identifier;

        CGSize imageSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
        CGFloat bytesPerPixel = 4.0;
        CGFloat bytesPerSize = imageSize.width * imageSize.height;
        self.totalBytes = (UInt64)bytesPerPixel * (UInt64)bytesPerSize;
        self.lastAccessDate = [NSDate date];
    }
    return self;
}
//上次获取缓存的时间
- (UIImage*)accessImage {
    self.lastAccessDate = [NSDate date];
    return self.image;
}

- (NSString *)description {
    NSString *descriptionString = [NSString stringWithFormat:@"Idenfitier: %@  lastAccessDate: %@ ", self.identifier, self.lastAccessDate];
    return descriptionString;

}

@end

@interface AFAutoPurgingImageCache ()
@property (nonatomic, strong) NSMutableDictionary <NSString* , AFCachedImage*> *cachedImages;
@property (nonatomic, assign) UInt64 currentMemoryUsage;
@property (nonatomic, strong) dispatch_queue_t synchronizationQueue;
@end

@implementation AFAutoPurgingImageCache

- (instancetype)init {
    //默认为内存100M，后者为缓存溢出后保留的内存
    return [self initWithMemoryCapacity:100 * 1024 * 1024 preferredMemoryCapacity:60 * 1024 * 1024];
}

- (instancetype)initWithMemoryCapacity:(UInt64)memoryCapacity preferredMemoryCapacity:(UInt64)preferredMemoryCapacity {
    if (self = [super init]) {
        //内存大小
        self.memoryCapacity = memoryCapacity;
        self.preferredMemoryUsageAfterPurge = preferredMemoryCapacity;
        //cache的字典
        self.cachedImages = [[NSMutableDictionary alloc] init];

        NSString *queueName = [NSString stringWithFormat:@"com.alamofire.autopurgingimagecache-%@", [[NSUUID UUID] UUIDString]];
        //并行的queue
        self.synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);

        //添加通知，收到内存警告的通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(removeAllImages)                  name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];

    }
    return self;
    /*
     1、声明了一个默认的内存缓存大小100M，还有一个意思是如果超出100M之后，我们去清除缓存，此时仍要保留的缓存大小60M。
     2、创建了一个并行queue，这个并行queue，这个类除了初始化以外，所有的方法都是在这个并行queue中调用的。
     3、创建了一个cache字典，我们所有的缓存数据，都被保存在这个字典中，key为url，value为AFCachedImage。
     
     这个类大量的使用了dispatch_barrier_sync与dispatch_barrier_async，可以参考如下文章
     这里没有用锁，但是因为使用了dispatch_barrier_sync，不仅同步了synchronizationQueue队列，而且阻塞了当前线程，所以保证了里面执行代码的线程安全问题。
     在这里其实使用锁也可以，但是AF在这的处理却是使用同步的机制来保证线程安全，或许这跟图片的加载缓存的使用场景，高频次有关系，在这里使用sync，并不需要在去开辟新的线程，浪费性能，只需要在原有线程，提交到synchronizationQueue队列中，阻塞的执行即可。这样省去大量的开辟线程与使用锁带来的性能消耗。
     [通过GCD中的dispatch_barrier_(a)sync加强对sync中所谓等待的理解 - 匪末的博客 - CSDN博客](https://blog.csdn.net/u013046795/article/details/47057585)
     
     */
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UInt64)memoryUsage {
    __block UInt64 result = 0;
    dispatch_sync(self.synchronizationQueue, ^{
        result = self.currentMemoryUsage;
    });
    return result;
}

- (void)addImage:(UIImage *)image withIdentifier:(NSString *)identifier {
    //用dispatch_barrier_async，来同步这个并行队列
    dispatch_barrier_async(self.synchronizationQueue, ^{
        //生成cache对象
        AFCachedImage *cacheImage = [[AFCachedImage alloc] initWithImage:image identifier:identifier];

        //去之前cache的字典里取
        AFCachedImage *previousCachedImage = self.cachedImages[identifier];
        //如果有被缓存过
        if (previousCachedImage != nil) {
            //当前已经使用的内存大小减去图片的大小
            self.currentMemoryUsage -= previousCachedImage.totalBytes;
        }

        //把新cache的image加上去
        self.cachedImages[identifier] = cacheImage;
        //加上内存大小
        self.currentMemoryUsage += cacheImage.totalBytes;
    });

    //做缓存溢出的清除，清除的是早期的缓存
    dispatch_barrier_async(self.synchronizationQueue, ^{
        //如果使用的内存大于我们设置的内存容量
        if (self.currentMemoryUsage > self.memoryCapacity) {
            //拿到使用内存 - 被清空后首选内存 =  需要被清除的内存
            UInt64 bytesToPurge = self.currentMemoryUsage - self.preferredMemoryUsageAfterPurge;
            //拿到所有缓存的数据
            NSMutableArray <AFCachedImage*> *sortedImages = [NSMutableArray arrayWithArray:self.cachedImages.allValues];
            //根据lastAccessDate排序 升序，越晚的越后面
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastAccessDate"
                                                                           ascending:YES];
            [sortedImages sortUsingDescriptors:@[sortDescriptor]];

            UInt64 bytesPurged = 0;

            //移除早期的cache bytesToPurge大小
            for (AFCachedImage *cachedImage in sortedImages) {
                [self.cachedImages removeObjectForKey:cachedImage.identifier];
                bytesPurged += cachedImage.totalBytes;
                if (bytesPurged >= bytesToPurge) {
                    break ;
                }
            }
            //移除早期的cache bytesToPurge大小
            self.currentMemoryUsage -= bytesPurged;
        }
    });
    /*
     主要做了两件事
     1、设置缓存到字典里，并且把对应的缓存大小设置到当前已缓存的数量属性中。
     2、判断是缓存超出了我们设置的最大缓存100M，如果是的话，则清除掉部分早时间的缓存，清除到缓存小于我们溢出后保留的内存60M以内。
     
     当然在这里更需要说一说的是dispatch_barrier_async，这里整个类都没有使用dispatch_async，所以不存在是为了做一个栅栏，来同步上下文的线程。其实它在本类中的作用很简单，就是一个串行执行。
     
     既然就是只是为了串行，那为什么我们不用一个串行queue就得了？非得用dispatch_barrier_async干嘛？之前我们说过，我们要用dispatch_barrier_sync来保证线程安全。如果我们使用串行queue,那么线程是极其容易死锁的。
     */
}

- (BOOL)removeImageWithIdentifier:(NSString *)identifier {
    __block BOOL removed = NO;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        AFCachedImage *cachedImage = self.cachedImages[identifier];
        if (cachedImage != nil) {
            [self.cachedImages removeObjectForKey:identifier];
            self.currentMemoryUsage -= cachedImage.totalBytes;
            removed = YES;
        }
    });
    return removed;
}
//移除所有图片
- (BOOL)removeAllImages {
    __block BOOL removed = NO;
    // 在这里用了dispatch_barrier_sync，因为synchronizationQueue是个并行queue，所以在这里不会出现死锁的问题。
    // 关于保证线程安全的同时，同步还是异步，与性能方面的考量，可以参考这篇文章：
    // [Objc的底层并发API](http://www.cocoachina.com/industry/20130821/6842.html)
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        if (self.cachedImages.count > 0) {
            [self.cachedImages removeAllObjects];
            self.currentMemoryUsage = 0;
            removed = YES;
        }
    });
    return removed;
}
//根据id获取图片
- (nullable UIImage *)imageWithIdentifier:(NSString *)identifier {
    __block UIImage *image = nil;
    //用同步的方式获取，防止线程安全问题
    dispatch_sync(self.synchronizationQueue, ^{
        AFCachedImage *cachedImage = self.cachedImages[identifier];
        //并且刷新获取的时间
        image = [cachedImage accessImage];
    });
    return image;
}

//根据request和additionalIdentifier添加image
- (void)addImage:(UIImage *)image forRequest:(NSURLRequest *)request withAdditionalIdentifier:(NSString *)identifier {
    [self addImage:image withIdentifier:[self imageCacheKeyFromURLRequest:request withAdditionalIdentifier:identifier]];
}
//根据request和additionalIdentifier移除图片
- (BOOL)removeImageforRequest:(NSURLRequest *)request withAdditionalIdentifier:(NSString *)identifier {
    return [self removeImageWithIdentifier:[self imageCacheKeyFromURLRequest:request withAdditionalIdentifier:identifier]];
}
//根据request和additionalIdentifier获取图片
- (nullable UIImage *)imageforRequest:(NSURLRequest *)request withAdditionalIdentifier:(NSString *)identifier {
    return [self imageWithIdentifier:[self imageCacheKeyFromURLRequest:request withAdditionalIdentifier:identifier]];
}
//根据request和additionalIdentifier获取图片
- (NSString *)imageCacheKeyFromURLRequest:(NSURLRequest *)request withAdditionalIdentifier:(NSString *)additionalIdentifier {
    NSString *key = request.URL.absoluteString;
    if (additionalIdentifier != nil) {
        key = [key stringByAppendingString:additionalIdentifier];
    }
    return key;
}

- (BOOL)shouldCacheImage:(UIImage *)image forRequest:(NSURLRequest *)request withAdditionalIdentifier:(nullable NSString *)identifier {
    return YES;
}

@end

#endif

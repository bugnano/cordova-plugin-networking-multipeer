// Taken from
// http://stackoverflow.com/questions/24710424/catch-an-exception-for-invalid-user-input-in-swift
@interface TryCatch: NSObject
+ (BOOL)tryBlock:(void(^)())tryBlock error:(NSError **)error;
@end


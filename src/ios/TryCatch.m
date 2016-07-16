// Taken from
// http://stackoverflow.com/questions/24710424/catch-an-exception-for-invalid-user-input-in-swift

#import "TryCatch.h"

@implementation TryCatch

+ (BOOL)tryBlock:(void(^)())tryBlock
								error:(NSError **)error
{
	@try {
		tryBlock ? tryBlock() : nil;
	}
	@catch (NSException *exception) {
		if (error) {
			*error = [NSError errorWithDomain:@"com.something"
										code:42
									userInfo:@{NSLocalizedDescriptionKey: exception.name}];
		}
		return NO;
	}
	return YES;
}

@end

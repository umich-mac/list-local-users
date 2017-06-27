#import <Foundation/Foundation.h>

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	CSIdentityQueryRef query;
	CFErrorRef error;
	CFArrayRef identityArray;
	NSFileHandle *stdout = [NSFileHandle fileHandleWithStandardOutput];

	// query CoreServices for all users
	query = CSIdentityQueryCreate(kCFAllocatorDefault, kCSIdentityClassUser, CSGetLocalIdentityAuthority());

	// execute the query (0 = don't give me hidden users; one-shot query, don't monitor for more later)
	if (CSIdentityQueryExecute(query, 0, &error))
	{
		// Get results from query
		identityArray = CSIdentityQueryCopyResults(query);

		// Enumerate
		for (CFIndex i = 0; i < CFArrayGetCount(identityArray); i++) {
			CSIdentityRef identity = (CSIdentityRef)CFArrayGetValueAtIndex(identityArray, i);

			// Extract username
			CFStringRef username = CSIdentityGetPosixName(identity);
						
			// And write
			NSString *output = [NSString stringWithFormat:@"%@\n", username];
			[stdout writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
	}
	CFRelease(query);
    [pool drain];
    return 0;
}

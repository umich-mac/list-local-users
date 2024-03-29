#import <Foundation/Foundation.h>
#import <Collaboration/Collaboration.h>

#include <getopt.h>

static int skipAdmins;
static int includePaths;
static int doHelp;

static struct option long_options[] =
{
    {"skip-admins",   no_argument, &skipAdmins, 1},
    {"include-paths", no_argument, &includePaths, 1},
    {"help",          no_argument, &doHelp, 1},
    {NULL, 0, NULL, 0}
};

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    NSString *output;

    while (getopt_long_only(argc, (char **)argv, "", long_options, NULL) != -1) {
        // loop through - we expect getopt to set the flags for us
    }

    // handle help argument
    if (doHelp) {
        printf("Usage: %s [--skip-admins] [--include-paths]\n", argv[0]);
        exit(0);
    }

	CSIdentityQueryRef query;
	CFErrorRef error;
	CFArrayRef identityArray;
    CSIdentityRef adminGroup;
	NSFileHandle *stdout = [NSFileHandle fileHandleWithStandardOutput];

    if (skipAdmins) {
        query = CSIdentityQueryCreateForPosixID(kCFAllocatorDefault, 80, kCSIdentityClassGroup, CSGetLocalIdentityAuthority());

        if (CSIdentityQueryExecute(query, 0, &error)) {
            identityArray = CSIdentityQueryCopyResults(query);
            if (CFArrayGetCount(identityArray) > 0) {
                adminGroup = (CSIdentityRef)CFArrayGetValueAtIndex(identityArray, 0);
            } else {
                skipAdmins = false;
            }
            CFRelease(identityArray);
        } else {
            skipAdmins = false;
        }
    }

	// query CoreServices for all users
	query = CSIdentityQueryCreate(kCFAllocatorDefault, kCSIdentityClassUser, CSGetLocalIdentityAuthority());

	// execute the query - one-shot query, don't monitor for more later
    // we include hidden identities because of a bug in Setup Assistant in macOS 12 (and later), which
    // produces an IsHidden setting that causes the SA-created user to be elided from the
    // query results.
    // filed as FB10523893, July 2022
	if (CSIdentityQueryExecute(query, kCSIdentityQueryIncludeHiddenIdentities, &error))
	{

		// Get results from query
		identityArray = CSIdentityQueryCopyResults(query);

		// Enumerate
		for (CFIndex i = 0; i < CFArrayGetCount(identityArray); i++) {
			CSIdentityRef identity = (CSIdentityRef)CFArrayGetValueAtIndex(identityArray, i);

            // skip if this is an admin and we're skipping admins
            if (skipAdmins && CSIdentityIsMemberOfGroup(identity, adminGroup)) {
                continue;
            }
            
            // check if this has the system FFFFEEEE UUID prefix
            // this is a patch for the above bug with IsHidden attributes
            CFUUIDRef uuid = CSIdentityGetUUID(identity);
            CFUUIDBytes bytes = CFUUIDGetUUIDBytes(uuid);
            if (bytes.byte0 == 0xFF && bytes.byte1 == 0xFF && bytes.byte2 == 0xEE && bytes.byte3 == 0xEE) {
                continue;
            }

			// Extract username
			CFStringRef username = CSIdentityGetPosixName(identity);

            if (includePaths) {
                output = [NSString stringWithFormat:@"%@\t%@\n", username, NSHomeDirectoryForUser((NSString *)username)];
            } else {
                output = [NSString stringWithFormat:@"%@\n", username];
            }
			[stdout writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
	}
	CFRelease(query);
    [pool drain];
    return 0;
}

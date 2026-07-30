#import <Foundation/Foundation.h>

///
/// Project-wide constants that live outside the code.
///
/// The GitHub owner and repository name appear in credits links, the issue
/// reporter, the package depiction and the APT source URL. Kept here so renaming
/// the repository is one edit rather than a hunt through twelve files.
///

#define SCIRepoOwner    @"ibrahim2100"
#define SCIRepoName     @"Albrhi-Repo"

#define SCIRepoURL      [NSString stringWithFormat:@"https://github.com/%@/%@", SCIRepoOwner, SCIRepoName]
#define SCIIssuesURL    [NSString stringWithFormat:@"%@/issues/new", SCIRepoURL]
#define SCISourceURL    [NSString stringWithFormat:@"https://%@.github.io/%@/", SCIRepoOwner, SCIRepoName]

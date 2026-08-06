#import "SCIPanelHelper.h"
#import "SCIPanelScan.h"

#import <spawn.h>
#import <sys/stat.h>
#import <sys/wait.h>

extern char **environ;

/// Where the helper lands, under whichever prefix this jailbreak uses.
static NSString *SCIHelperPath(void) {
    return [[SCIPanelScan jailbreakPrefix]
        stringByAppendingPathComponent:@"usr/libexec/albrhipanelhelper"];
}

BOOL SCIPanelHelperReady(void) {
    struct stat info;
    if (stat(SCIHelperPath().fileSystemRepresentation, &info) != 0) return NO;

    // Present is not enough. Without the setuid bit it runs as mobile, cannot write a
    // root-owned filter, and every switch fails with nothing on screen to explain it.
    return (info.st_mode & S_ISUID) && info.st_uid == 0;
}

BOOL SCIPanelSetTweak(NSString *filterFileName,
                      NSString *bundleIdentifier,
                      BOOL enabled,
                      NSError **error) {

    NSString *helper = SCIHelperPath();

    char *arguments[] = {
        (char *)helper.fileSystemRepresentation,
        "set",
        (char *)filterFileName.UTF8String,
        (char *)bundleIdentifier.UTF8String,
        (char *)(enabled ? "on" : "off"),
        NULL
    };

    pid_t pid = 0;
    int spawned = posix_spawn(&pid, helper.fileSystemRepresentation, NULL, NULL,
                              arguments, environ);
    if (spawned != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.albrhi.panel"
                                         code:spawned
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"The helper could not be started."}];
        }
        return NO;
    }

    // Waited for rather than fired and forgotten: the switch has to show whether the write
    // happened, and a switch that reports success before the work is done is a switch that
    // lies for the half-second before it flips back.
    int status = 0;
    while (waitpid(pid, &status, 0) == -1 && errno == EINTR) { }

    BOOL ok = WIFEXITED(status) && WEXITSTATUS(status) == 0;
    if (!ok && error) {
        *error = [NSError errorWithDomain:@"com.albrhi.panel"
                                     code:WIFEXITED(status) ? WEXITSTATUS(status) : -1
                                 userInfo:@{NSLocalizedDescriptionKey:
                                     @"The helper refused the change."}];
    }
    return ok;
}

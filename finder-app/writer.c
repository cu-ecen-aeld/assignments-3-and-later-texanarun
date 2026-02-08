#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <libgen.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <syslog.h>
#include <fcntl.h>
#include <unistd.h>

/* Recursive mkdir -p equivalent */
static int mkdir_p(const char *path, mode_t mode) {
    char tmp[1024];
    snprintf(tmp, sizeof(tmp), "%s", path);

    size_t len = strlen(tmp);
    if (len == 0)
        return -1;

    if (tmp[len - 1] == '/')
        tmp[len - 1] = '\0';

    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(tmp, mode) != 0 && errno != EEXIST)
                return -1;
            *p = '/';
        }
    }

    if (mkdir(tmp, mode) != 0 && errno != EEXIST)
        return -1;

    return 0;
}

int main(int argc, char *argv[])
{
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Incorrect arguments provided");
        closelog();
        return 1;
    }

    const char *writepath = argv[1];
    const char *writestr  = argv[2];

    char path_copy[1024];
    snprintf(path_copy, sizeof(path_copy), "%s", writepath);

    char *writedir = dirname(path_copy);

    syslog(LOG_DEBUG, "Writer Path: %s", writepath);
    syslog(LOG_DEBUG, "Writer Dir: %s", writedir);

    /* Check if directory exists, create if not */
    struct stat st;
    if (stat(writedir, &st) != 0) {
        syslog(LOG_INFO, "Directory does not exist, creating: %s", writedir);
        if (mkdir_p(writedir, 0755) != 0) {
            syslog(LOG_ERR, "Failed to create directory %s: %s", writedir, strerror(errno));
            closelog();
            return 1;
        }
    } else if (!S_ISDIR(st.st_mode)) {
        syslog(LOG_ERR, "Path exists but is not a directory: %s", writedir);
        closelog();
        return 1;
    }

    /* Write string using open/write for reliability */
    int fd = open(writepath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        syslog(LOG_ERR, "open failed for %s: %s", writepath, strerror(errno));
        closelog();
        return 1;
    }

    ssize_t len = strlen(writestr);
    if (write(fd, writestr, len) != len) {
        syslog(LOG_ERR, "write failed for %s: %s", writepath, strerror(errno));
        close(fd);
        closelog();
        return 1;
    }

    /* optional newline */
    write(fd, "\n", 1);

    close(fd);

    syslog(LOG_INFO, "Successfully wrote '%s' to %s", writestr, writepath);
    closelog();
    return 0;
}


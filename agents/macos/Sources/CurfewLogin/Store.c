#include "CurfewLogin.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static const char *approved = "approved";
static const char *secret = "secret";

int curfew_valid_name(const char *name) {
    if (name == NULL || name[0] == '\0' || name[0] == '.' || name[0] == '-') return 0;
    size_t length = 0;
    for (const char *c = name; *c; c++, length++) {
        int ok = (*c >= 'a' && *c <= 'z') || (*c >= 'A' && *c <= 'Z') || (*c >= '0' && *c <= '9') ||
                 *c == '_' || *c == '-' || *c == '.';
        if (!ok || length >= 255) return 0;
    }
    return 1;
}

static int path_for(char *path, const char *dir, const char *kind, const char *name) {
    if (!curfew_valid_name(name)) return 0;
    int written = snprintf(path, PATH_MAX, "%s/%s/%s", dir, kind, name);
    return written > 0 && written < PATH_MAX - 8;
}

static int make_folders(const char *dir, const char *kind) {
    char folder[PATH_MAX];
    if (snprintf(folder, sizeof folder, "%s/%s", dir, kind) >= (int)sizeof folder) return 0;
    if (mkdir(dir, 0700) != 0 && errno != EEXIST) return 0;
    if (mkdir(folder, 0700) != 0 && errno != EEXIST) return 0;
    struct stat info;
    return lstat(folder, &info) == 0 && S_ISDIR(info.st_mode) && info.st_uid == geteuid() && (info.st_mode & 077) == 0;
}

static int write_file(const char *dir, const char *kind, const char *name, const char *data, size_t length) {
    char path[PATH_MAX];
    char temporary[PATH_MAX];
    if (!path_for(path, dir, kind, name) || !make_folders(dir, kind)) return 0;
    snprintf(temporary, sizeof temporary, "%s.new", path);
    unlink(temporary);
    int descriptor = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (descriptor < 0) return 0;
    size_t sent = 0;
    while (sent < length) {
        ssize_t count = write(descriptor, data + sent, length - sent);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) break;
        sent += (size_t)count;
    }
    int ok = sent == length && fsync(descriptor) == 0;
    close(descriptor);
    if (!ok || rename(temporary, path) != 0) {
        unlink(temporary);
        return 0;
    }
    return 1;
}

static long read_file(const char *path, char *buffer, size_t capacity) {
    int descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) return -1;
    struct stat info;
    if (fstat(descriptor, &info) != 0 || !S_ISREG(info.st_mode) || info.st_uid != geteuid() ||
        (info.st_mode & 077) != 0 || info.st_size <= 0 || (size_t)info.st_size >= capacity) {
        close(descriptor);
        return -1;
    }
    size_t got = 0;
    while (got < (size_t)info.st_size) {
        ssize_t count = read(descriptor, buffer + got, (size_t)info.st_size - got);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) break;
        got += (size_t)count;
    }
    close(descriptor);
    if (got != (size_t)info.st_size) return -1;
    buffer[got] = '\0';
    return (long)got;
}

int curfew_approve(const char *dir, const char *name, double deadline) {
    char text[64];
    int length = snprintf(text, sizeof text, "%.3f\n", deadline);
    return length > 0 && write_file(dir, approved, name, text, (size_t)length);
}

int curfew_take_approval(const char *dir, const char *name, double now) {
    char path[PATH_MAX];
    char text[64];
    if (!path_for(path, dir, approved, name)) return 0;
    long length = read_file(path, text, sizeof text);
    unlink(path);
    if (length <= 0) return 0;
    char *end = NULL;
    double deadline = strtod(text, &end);
    return end != text && deadline >= now && deadline - now <= 600;
}

void curfew_revoke(const char *dir, const char *name) {
    char path[PATH_MAX];
    if (path_for(path, dir, approved, name)) unlink(path);
}

int curfew_knows(const char *dir, const char *name) {
    char path[PATH_MAX];
    struct stat info;
    return path_for(path, dir, secret, name) && lstat(path, &info) == 0 && S_ISREG(info.st_mode) && info.st_size > 0;
}

int curfew_remember(const char *dir, const char *name, const char *data, size_t length) {
    if (data == NULL || length == 0 || length > CURFEW_SECRET_MAX) return 0;
    return write_file(dir, secret, name, data, length);
}

long curfew_recall(const char *dir, const char *name, char *buffer, size_t capacity) {
    char path[PATH_MAX];
    if (buffer == NULL || capacity == 0 || !path_for(path, dir, secret, name)) return -1;
    return read_file(path, buffer, capacity);
}

long curfew_fill_login(const char *dir, const char *name, long typed, double now, char *buffer, size_t capacity) {
    if (typed > 0 || !curfew_valid_name(name) || !curfew_take_approval(dir, name, now)) return -1;
    return curfew_recall(dir, name, buffer, capacity);
}

int curfew_should_remember(const char *name, long typed) {
    return typed > 0 && typed <= CURFEW_SECRET_MAX && curfew_valid_name(name);
}

int curfew_allow_unlock(const char *dir, const char *console, double now) {
    return curfew_valid_name(console) && curfew_take_approval(dir, console, now);
}

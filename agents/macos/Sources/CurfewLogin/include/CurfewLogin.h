#ifndef CURFEW_LOGIN_H
#define CURFEW_LOGIN_H

#include <stddef.h>

#define CURFEW_LOGIN_DIR "/Library/Application Support/Curfew/Login"
#define CURFEW_SECRET_MAX 1024

int curfew_valid_name(const char *name);
int curfew_approve(const char *dir, const char *name, double deadline);
int curfew_take_approval(const char *dir, const char *name, double now);
void curfew_revoke(const char *dir, const char *name);
int curfew_knows(const char *dir, const char *name);
int curfew_remember(const char *dir, const char *name, const char *secret, size_t length);
long curfew_recall(const char *dir, const char *name, char *buffer, size_t capacity);

long curfew_fill_login(const char *dir, const char *name, long typed, double now, char *secret, size_t capacity);
int curfew_should_remember(const char *name, long typed);
int curfew_allow_unlock(const char *dir, const char *console, double now);

#endif

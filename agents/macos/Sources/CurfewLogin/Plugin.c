#define __STDC_WANT_LIB_EXT1__ 1
#include "CurfewLogin.h"

#include <Security/AuthorizationPlugin.h>
#include <Security/AuthorizationTags.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

typedef enum { MechanismLogin, MechanismRemember, MechanismUnlock } MechanismKind;

typedef struct {
    const AuthorizationCallbacks *callbacks;
} Plugin;

typedef struct {
    Plugin *plugin;
    AuthorizationEngineRef engine;
    MechanismKind kind;
} Mechanism;

static os_log_t journal(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.rafay99.curfew", "login"); });
    return log;
}

static double now(void) {
    struct timeval time;
    gettimeofday(&time, NULL);
    return (double)time.tv_sec + (double)time.tv_usec / 1e6;
}

static long copy_value(const AuthorizationValue *value, char *out, size_t capacity) {
    if (value == NULL || value->data == NULL) return -1;
    size_t length = strnlen(value->data, value->length);
    if (length >= capacity) return (long)capacity;
    memcpy(out, value->data, length);
    out[length] = '\0';
    return (long)length;
}

static long context_text(Mechanism *mechanism, const char *key, char *out, size_t capacity) {
    AuthorizationContextFlags flags = 0;
    const AuthorizationValue *value = NULL;
    if (mechanism->plugin->callbacks->GetContextValue(mechanism->engine, key, &flags, &value) != errAuthorizationSuccess) return -1;
    return copy_value(value, out, capacity);
}

static long user_name(Mechanism *mechanism, char *out, size_t capacity) {
    long length = context_text(mechanism, kAuthorizationEnvironmentUsername, out, capacity);
    if (length > 0 && (size_t)length < capacity) return length;
    const AuthorizationValue *value = NULL;
    if (mechanism->plugin->callbacks->GetHintValue(mechanism->engine, kAuthorizationEnvironmentUsername, &value) != errAuthorizationSuccess) return -1;
    return copy_value(value, out, capacity);
}

static int console_user(char *out, size_t capacity) {
    CFStringRef name = SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL);
    if (name == NULL) return 0;
    Boolean ok = CFStringGetCString(name, out, (CFIndex)capacity, kCFStringEncodingUTF8);
    CFRelease(name);
    return ok;
}

static AuthorizationResult login(Mechanism *mechanism) {
    char name[256] = {0};
    char typed[CURFEW_SECRET_MAX + 2] = {0};
    char secret[CURFEW_SECRET_MAX + 2] = {0};
    user_name(mechanism, name, sizeof name);
    long typedLength = context_text(mechanism, kAuthorizationEnvironmentPassword, typed, sizeof typed);
    long length = curfew_fill_login(CURFEW_LOGIN_DIR, name, typedLength, now(), secret, sizeof secret);
    if (length > 0) {
        AuthorizationValue value = {(size_t)length, secret};
        OSStatus status = mechanism->plugin->callbacks->SetContextValue(
            mechanism->engine, kAuthorizationEnvironmentPassword, kAuthorizationContextFlagExtractable, &value);
        os_log(journal(), "phone login for %{public}s: %{public}s", name, status == errAuthorizationSuccess ? "filled in" : "failed");
    }
    memset_s(typed, sizeof typed, 0, sizeof typed);
    memset_s(secret, sizeof secret, 0, sizeof secret);
    return kAuthorizationResultAllow;
}

static AuthorizationResult remember(Mechanism *mechanism) {
    char name[256] = {0};
    char typed[CURFEW_SECRET_MAX + 2] = {0};
    user_name(mechanism, name, sizeof name);
    long length = context_text(mechanism, kAuthorizationEnvironmentPassword, typed, sizeof typed);
    if (curfew_should_remember(name, length) && !curfew_remember(CURFEW_LOGIN_DIR, name, typed, (size_t)length)) {
        os_log(journal(), "could not keep the password of %{public}s", name);
    }
    memset_s(typed, sizeof typed, 0, sizeof typed);
    return kAuthorizationResultAllow;
}

static AuthorizationResult unlock(void) {
    char name[256] = {0};
    if (!console_user(name, sizeof name) || !curfew_allow_unlock(CURFEW_LOGIN_DIR, name, now())) return kAuthorizationResultDeny;
    os_log(journal(), "phone unlock for %{public}s", name);
    return kAuthorizationResultAllow;
}

static OSStatus plugin_destroy(AuthorizationPluginRef plugin) {
    free(plugin);
    return errAuthorizationSuccess;
}

static OSStatus mechanism_create(AuthorizationPluginRef plugin, AuthorizationEngineRef engine, AuthorizationMechanismId id,
                                 AuthorizationMechanismRef *out) {
    MechanismKind kind;
    if (strcmp(id, "login") == 0) kind = MechanismLogin;
    else if (strcmp(id, "remember") == 0) kind = MechanismRemember;
    else if (strcmp(id, "unlock") == 0) kind = MechanismUnlock;
    else return errAuthorizationInternal;
    Mechanism *mechanism = calloc(1, sizeof *mechanism);
    if (mechanism == NULL) return errAuthorizationInternal;
    mechanism->plugin = plugin;
    mechanism->engine = engine;
    mechanism->kind = kind;
    *out = mechanism;
    return errAuthorizationSuccess;
}

static OSStatus mechanism_invoke(AuthorizationMechanismRef reference) {
    Mechanism *mechanism = reference;
    AuthorizationResult result;
    switch (mechanism->kind) {
    case MechanismLogin: result = login(mechanism); break;
    case MechanismRemember: result = remember(mechanism); break;
    case MechanismUnlock: result = unlock(); break;
    }
    return mechanism->plugin->callbacks->SetResult(mechanism->engine, result);
}

static OSStatus mechanism_deactivate(AuthorizationMechanismRef reference) {
    Mechanism *mechanism = reference;
    return mechanism->plugin->callbacks->DidDeactivate(mechanism->engine);
}

static OSStatus mechanism_destroy(AuthorizationMechanismRef reference) {
    free(reference);
    return errAuthorizationSuccess;
}

static AuthorizationPluginInterface interface = {
    kAuthorizationPluginInterfaceVersion, plugin_destroy, mechanism_create, mechanism_invoke, mechanism_deactivate, mechanism_destroy,
};

__attribute__((visibility("default"))) OSStatus AuthorizationPluginCreate(const AuthorizationCallbacks *callbacks,
                                                                         AuthorizationPluginRef *outPlugin,
                                                                         const AuthorizationPluginInterface **outInterface) {
    Plugin *plugin = calloc(1, sizeof *plugin);
    if (plugin == NULL) return errAuthorizationInternal;
    plugin->callbacks = callbacks;
    *outPlugin = plugin;
    *outInterface = &interface;
    return errAuthorizationSuccess;
}

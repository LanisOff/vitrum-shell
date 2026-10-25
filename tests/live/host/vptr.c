/*
 * vptr — a virtual pointer that can hold its button, for drags in the nested
 * test session (wlrctl only clicks). One process runs the whole gesture, so
 * the button stays down between moves:
 *   vptr to X Y | go X Y [steps] [ms] | down [left|right|middle] | up [...] | wait MS | run CMD
 *     to    jump to output pixels (relative motion from -20000,-20000, as wlrctl)
 *     go    glide there from the last position in small steps (default 12, 16 ms)
 *     run   a shell command while the button is held (a screenshot mid-drag)
 * Runs only on the display in WAYLAND_DISPLAY; nested-remote.sh guards that.
 * Build: see nested-remote.sh (wayland-scanner + cc against wayland-client).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct wl_seat *seat;
static struct zwlr_virtual_pointer_manager_v1 *mgr;
static struct wl_display *dpy;
static struct zwlr_virtual_pointer_v1 *ptr;
static double cx, cy;

static void reg_global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    (void)d;
    if (!strcmp(iface, wl_seat_interface.name) && !seat)
        seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
    else if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
        mgr = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
    (void)ver;
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) { (void)d; (void)r; (void)name; }
static const struct wl_registry_listener reg = { reg_global, reg_remove };

static uint32_t now(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000);
}
static void sleep_ms(int ms) { struct timespec t = { ms / 1000, (long)(ms % 1000) * 1000000L }; nanosleep(&t, NULL); }
static void motion(double dx, double dy) {
    zwlr_virtual_pointer_v1_motion(ptr, now(), wl_fixed_from_double(dx), wl_fixed_from_double(dy));
    zwlr_virtual_pointer_v1_frame(ptr);
    wl_display_roundtrip(dpy);
}
static uint32_t button(const char *b) {
    if (b && !strcmp(b, "right")) return 0x111;
    if (b && !strcmp(b, "middle")) return 0x112;
    return 0x110;   /* BTN_LEFT */
}

int main(int argc, char **argv) {
    dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "vptr: no display\n"); return 1; }
    struct wl_registry *r = wl_display_get_registry(dpy);
    wl_registry_add_listener(r, &reg, NULL);
    wl_display_roundtrip(dpy);
    if (!mgr) { fprintf(stderr, "vptr: no zwlr_virtual_pointer_manager_v1\n"); return 1; }
    ptr = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr, seat);
    wl_display_roundtrip(dpy);
    for (int i = 1; i < argc; i++) {
        const char *op = argv[i];
        const char *a1 = i + 1 < argc ? argv[i + 1] : NULL;
        if (!strcmp(op, "to") && i + 2 < argc) {
            motion(-20000, -20000);
            cx = atof(argv[i + 1]); cy = atof(argv[i + 2]); i += 2;
            motion(cx, cy);
        } else if (!strcmp(op, "go") && i + 2 < argc) {
            double tx = atof(argv[i + 1]), ty = atof(argv[i + 2]); i += 2;
            int steps = 12, ms = 16;
            if (i + 1 < argc && argv[i + 1][0] >= '0' && argv[i + 1][0] <= '9') steps = atoi(argv[++i]);
            if (i + 1 < argc && argv[i + 1][0] >= '0' && argv[i + 1][0] <= '9') ms = atoi(argv[++i]);
            if (steps < 1) steps = 1;
            double sx = cx, sy = cy;
            for (int k = 1; k <= steps; k++) {
                double nx = sx + (tx - sx) * k / steps, ny = sy + (ty - sy) * k / steps;
                motion(nx - cx, ny - cy); cx = nx; cy = ny;
                sleep_ms(ms);
            }
        } else if (!strcmp(op, "down") || !strcmp(op, "up")) {
            const char *b = a1 && (!strcmp(a1, "left") || !strcmp(a1, "right") || !strcmp(a1, "middle")) ? argv[++i] : "left";
            zwlr_virtual_pointer_v1_button(ptr, now(), button(b), !strcmp(op, "down") ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
            zwlr_virtual_pointer_v1_frame(ptr);
            wl_display_roundtrip(dpy);
        } else if (!strcmp(op, "wait") && a1) {
            sleep_ms(atoi(argv[++i]));
        } else if (!strcmp(op, "run") && a1) {
            if (system(argv[++i]) != 0) fprintf(stderr, "vptr: run failed: %s\n", argv[i]);
        } else {
            fprintf(stderr, "vptr: bad op '%s'\n", op);
            return 2;
        }
    }
    zwlr_virtual_pointer_v1_destroy(ptr);
    wl_display_roundtrip(dpy);
    wl_display_disconnect(dpy);
    return 0;
}

/*
 * selinux_hide 实机验证程序。
 *
 * 以 root 启动后先 setgid/setuid 到指定 uid（>=10000 才会命中 hide 钩子），
 * 再按参数操作 selinuxfs 的节点。所有结果打印成一行，便于主机侧比对。
 *
 * 编译：
 *   aarch64-linux-gnu-gcc -static -O2 -o .tmp/seltest tools/device/seltest.c
 *   adb push .tmp/seltest /data/local/tmp/seltest
 *
 * 用法：
 *   seltest <uid> context <ctx>
 *   seltest <uid> access <scon> <tcon> <tclass>
 *   seltest <uid> setcon <ctx>
 *   seltest <uid> status
 *   seltest <uid> show
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

struct selinux_kernel_status {
    unsigned int version;
    unsigned int sequence;
    unsigned int enforcing;
    unsigned int policyload;
    unsigned int deny_unknown;
} __attribute__((packed));

static int write_path(const char *path, const char *data, size_t len, char *resp, size_t resp_len)
{
    int fd;
    ssize_t n;
    int rc;

    fd = open(path, O_RDWR);
    if (fd < 0)
        return -errno;

    n = write(fd, data, len);
    rc = (n < 0) ? -errno : (int)n;

    if (resp && resp_len) {
        ssize_t r = read(fd, resp, resp_len - 1);
        if (r > 0) {
            resp[r] = '\0';
            /* 去掉尾部换行 */
            while (r > 0 && (resp[r - 1] == '\n' || resp[r - 1] == '\0'))
                resp[--r] = '\0';
        } else {
            resp[0] = '\0';
        }
    }

    close(fd);
    return rc;
}

int main(int argc, char **argv)
{
    unsigned uid;
    const char *mode;
    char resp[512];

    if (argc < 3) {
        fprintf(stderr, "usage: %s <uid> <mode> [args...]\n", argv[0]);
        return 2;
    }

    uid = (unsigned)strtoul(argv[1], NULL, 10);
    mode = argv[2];

    if (uid != 0) {
        if (setgroups(1, (gid_t[]){ (gid_t)uid }) != 0) {
            fprintf(stderr, "setgroups failed: %s\n", strerror(errno));
            return 1;
        }
        if (setgid(uid) != 0 || setuid(uid) != 0) {
            fprintf(stderr, "setuid failed: %s\n", strerror(errno));
            return 1;
        }
    }

    if (!strcmp(mode, "show")) {
        resp[0] = '\0';
        int fd = open("/proc/self/attr/current", O_RDONLY);
        if (fd >= 0) {
            ssize_t r = read(fd, resp, sizeof(resp) - 1);
            if (r > 0)
                resp[r] = '\0';
            close(fd);
        }
        while (strlen(resp) && (resp[strlen(resp) - 1] == '\n' || resp[strlen(resp) - 1] == '\0'))
            resp[strlen(resp) - 1] = '\0';
        printf("uid=%u euid=%u context=%s\n", getuid(), geteuid(), resp);
        return 0;
    }

    if (!strcmp(mode, "context")) {
        if (argc < 4)
            return 2;
        int rc = write_path("/sys/fs/selinux/context", argv[3], strlen(argv[3]), resp, sizeof(resp));
        printf("uid=%u write context '%s' rc=%d resp='%s'\n", getuid(), argv[3], rc, resp);
        return 0;
    }

    if (!strcmp(mode, "access")) {
        char req[512];
        if (argc < 6)
            return 2;
        snprintf(req, sizeof(req), "%s %s %s", argv[3], argv[4], argv[5]);
        int rc = write_path("/sys/fs/selinux/access", req, strlen(req), resp, sizeof(resp));
        printf("uid=%u write access '%s' rc=%d resp='%s'\n", getuid(), req, rc, resp);
        return 0;
    }

    if (!strcmp(mode, "setcon")) {
        if (argc < 4)
            return 2;
        int rc = write_path("/proc/self/attr/current", argv[3], strlen(argv[3]), NULL, 0);
        printf("uid=%u write attr/current '%s' rc=%d\n", getuid(), argv[3], rc);
        return 0;
    }

    if (!strcmp(mode, "status")) {
        struct selinux_kernel_status st;
        int fd = open("/sys/fs/selinux/status", O_RDONLY);
        if (fd < 0) {
            printf("uid=%u open status failed: %d\n", getuid(), -errno);
            return 1;
        }
        memset(&st, 0, sizeof(st));
        ssize_t r = read(fd, &st, sizeof(st));
        close(fd);
        printf("uid=%u read=%zd version=%u sequence=%u enforcing=%u policyload=%u deny_unknown=%u\n", getuid(), r,
               st.version, st.sequence, st.enforcing, st.policyload, st.deny_unknown);
        return 0;
    }

    fprintf(stderr, "unknown mode: %s\n", mode);
    return 2;
}

/*
 * 以指定 uid 执行命令，可选先脱离当前进程树并切换 SELinux 上下文。
 * 用法：dropuid [--orphan] [--shell] <uid> <command> [args...]
 *
 * --orphan 通过两次 fork 与 setsid 让子进程挂到 init 下，用于验证
 * shell_su_adb_only 对非 adbd 后代的判定。
 * --shell 在降权后把上下文切到 u:r:shell:s0，避免进程本身仍处于 ksu 域。
 *
 * 经 adb shell 启动时，切换上下文后原 stdout 可能被 SELinux 拒绝，
 * 建议把输出重定向到文件。
 */
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void die(const char *msg)
{
    perror(msg);
    exit(1);
}

static void set_shell_context(void)
{
    static const char context[] = "u:r:shell:s0";
    int fd = open("/proc/self/attr/current", O_WRONLY);

    if (fd < 0)
        die("open attr/current");
    if (write(fd, context, sizeof(context) - 1) != (ssize_t)(sizeof(context) - 1))
        die("write attr/current");
    close(fd);
}

int main(int argc, char **argv)
{
    int i = 1, orphan = 0, shell = 0;
    uid_t uid;

    if (i < argc && strcmp(argv[i], "--orphan") == 0) {
        orphan = 1;
        i++;
    }
    if (i < argc && strcmp(argv[i], "--shell") == 0) {
        shell = 1;
        i++;
    }
    if (i + 1 >= argc) {
        fprintf(stderr, "用法: %s [--orphan] [--shell] <uid> <command> [args...]\n", argv[0]);
        return 2;
    }
    uid = (uid_t)strtoul(argv[i++], NULL, 10);

    if (orphan) {
        pid_t pid = fork();
        if (pid < 0)
            die("fork");
        if (pid > 0)
            _exit(0);
        if (setsid() < 0)
            die("setsid");
        pid = fork();
        if (pid < 0)
            die("fork2");
        if (pid > 0)
            _exit(0);
    }

    if (setgroups(0, NULL) != 0)
        die("setgroups");
    if (setgid(uid) != 0)
        die("setgid");
    if (setuid(uid) != 0)
        die("setuid");

    if (shell)
        set_shell_context();

    printf("dropuid: uid=%u ppid=%d\n", (unsigned)getuid(), (int)getppid());
    fflush(stdout);
    execvp(argv[i], &argv[i]);
    die("execvp");
    return 1;
}

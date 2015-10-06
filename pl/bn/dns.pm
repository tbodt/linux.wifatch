#
# This file is part of Linux.Wifatch
#
# Copyright (c) 2013,2014,2015 The White Team <rav7teif@ya.ru>
#
# Linux.Wifatch is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Linux.Wifatch is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Linux.Wifatch. If not, see <http://www.gnu.org/licenses/>.
#

package bn::dns;

my @cfg = (max_outstanding => 16,
	   timeout         => [1, 2, 4, 8, 16, 24],
	   search          => [],
	   ndots           => 1
);
my @dns_test = qw(google.com ietf.org berkeley.edu);

$AnyEvent::DNS::RESOLVER = new AnyEvent::DNS @cfg,
	server => \@AnyEvent::DNS::DNS_FALLBACK;

for (@dns_test) {
	AnyEvent::DNS::ns $_, Coro::rouse_cb;
	return 1 if Coro::rouse_wait;
}

bn::log "DNS first round failure";

$AnyEvent::DNS::RESOLVER = new AnyEvent::DNS @cfg,
	server => \@AnyEvent::DNS::DNS_FALLBACK;
$AnyEvent::DNS::RESOLVER->os_config;
$AnyEvent::DNS::RESOLVER->{search} = [];
$AnyEvent::DNS::RESOLVER->_compile;

for (@dns_test) {
	AnyEvent::DNS::ns $_, Coro::rouse_cb;
	return 1 if Coro::rouse_wait;
}

bn::log "DNS failure";

# failure
$bn::SAFE_MODE   ||= 1;
$bn::SAFE_STATUS ||= "dns";

1


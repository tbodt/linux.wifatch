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

package bn::upgrade;

# whispernet upgrades, node-to-node

our %SRC;         # source nodes where upgrade found [$plversion, $failcount]
our $UPGRADER;    # the upgrade coro

use bn::auto sub => <<'END';
sub upgrader();
my $guard = Guard::guard {
	bn::log "upgrader: stopping";
	undef $UPGRADER;
};

bn::log "upgrader: starting";

while (%SRC) {

	# as long as there are possible sources
	for my $src (keys %SRC) {
		my $v = $SRC{$src};

		bn::log "upgrader: getting pl from " . bn::func::id2str $src;
		if (bn::fileclient::download_from $src,
		     1, $v->[0], "$::BASE/.net_plw") {

			# pl is there, now test it

			if (bn::crypto::file_sigcheck "$::BASE/.net_plw",
			     "pl") {
				bn::log
					"upgrader: plw downloaded and sigverified";

				# now check version and try get the bn
				my $pl = plpack::load "$::BASE/.net_plw";
				my $wh =
					CBOR::XS::decode_cbor
					Compress::LZF::decompress $pl->(
								    "!whisper");

				if ($wh->{plversion} > $bn::PLVERSION) {
					if (my $bn =
					     $wh->{file}{"$bn::BNARCH/bn"}) {
						if ( $bn->[1] eq eval {
							     bn::func::file_sha256
								     "$::BASE/.net_bn";
						     }
						     or $wh->{skipbn}
							) {
							bn::log
								"upgrader: we already have bn, quelle joie!";
							if ( rename
							     "$::BASE/.net_plw",
							     "$::BASE/.net_pl"
								) {
								if ( $bn::REEXEC_FAILED
									) {
									bn::log
										"UP previous reexec failed";
									syswrite
										$bn::SAFE_PIPE,
										chr
										254;
									bn::func::restart_in_5;
								} else {
									bn::event::inject
										"save";
									bn::event::inject
										"upgrade";
									syswrite
										$bn::SAFE_PIPE,
										chr
										254;
									POSIX::_exit
										1
										;
								}
							}
						} else {
							bn::log
								"upgrader: fetching bn not yet implemented";
						}
					} else {
						bn::log
							"upgrader: no file for arch $bn::BNARCH";
					}
				} else {
					bn::log
						"upgrader: bad - downloaded plversion $wh->{plversion}, mine is $bn::PLVERSION";
				}

				# fail...
				unlink "$::BASE/.net_plw";
				Coro::AnyEvent::sleep 600;
			} else {
				bn::log
					"upgrader: signature verification failed";
			}
		}

		delete $SRC{$src} if ++$v->[1] > 10;
		Coro::AnyEvent::sleep 5;
	}

	Coro::AnyEvent::sleep 20 + rand 80;
}

END

bn::event::on hpv_add => sub {
	bn::hpv::whisper $_[0], 1, pack "w", $bn::PLVERSION unless ::DEBUG;
};

bn::event::on hpv_w1 => sub {
	my ($src, $data) = @_;

	my ($pl) = unpack "w", $data;

	return unless $pl > $bn::PLVERSION;

	bn::log "upgrader: newer plversion $pl on " . bn::func::id2str $src;

	$SRC{$src} = [$pl];

	$UPGRADER ||= &bn::func::async(\&upgrader);
};

1


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

package bn::xx;

# extension management

#   0 - malsigs.cbor
#   1 - seeds
#   2 - temp patches
#   3 - readme(?)
#   4 - backchannel

our $I;    # current index during call
our @PL;
our @SEQ;

sub call($$;@)
{
	my $i    = shift;
	my $name = shift;

	local $I = $i;
	my $pl = $PL[$I] or return;

	my @r = eval "package bn::xx$I;\n#line 0 'XX$I'\n" . $pl->("$name.pl");
	bn::log "bn::xx XX$i $name: $@\n" if $@;

	@r
}

sub unload
{
	my ($i) = @_;

	bn::event::inject "unloadxx", $i, $PL[$i];
	bn::event::inject "unloadxx$i", $PL[$i];
	call $i, "unload";

	undef $PL[$i];
	undef $SEQ[$i];
}

sub load($;$)
{
	my ($i, $flags) = @_;

	# flags 0 - normal load
	# flags 1 - on boot

	if (my $pl = plpack::load "$::BASE/.net_$i") {
		if ($pl->("ver") == $bn::PLVERSION) {
			bn::log "bn::xx XX$i loading";

			unload $i;

			$PL[$i]  = $pl;
			$SEQ[$i] = $pl->("seq") + 0;

			call $i, "load", $flags;
			bn::event::inject "loadxx$i", $PL[$i];
			bn::event::inject "loadxx", $i, $PL[$i];
		} else {
			bn::log "bn::xx XX$i ver mismatch";

			Coro::AnyEvent::sleep 15;
		}
	}
}

our $QUEUE = new Coro::Channel;
our $MANAGER;

sub init
{
	$MANAGER = bn::func::async {
		Coro::AnyEvent::sleep 60
			unless ::DEBUG
			; # deadtime after boot, to allow software updates or connects to go through

		if (opendir my $dir, $::BASE) {
			for (readdir $dir) {
				if (/^\.net_(\d+)$/) {
					load $1, 1;
					whisper;
				}
			}
		}

		my $job;

		$job->() while $job = $QUEUE->get;
	};
}

sub whisper_to($)
{
	bn::hpv::whisper $_[0], 2, pack "w*", @SEQ unless ::DEBUG;
}

# bn::xx::whisper_to $_ for keys %bn::hpv::as;

sub whisper(;$)
{
	whisper_to $_ for grep $_ ne $_[0], keys %bn::hpv::as;
}

bn::event::on hpv_add => \&whisper_to;

bn::event::on hpv_w2 => sub {
	my ($src, $data) = @_;

	$QUEUE->put(
		sub {
			my $delay;
			my @seq = unpack "w*", $data;

			for my $i (0 .. $#seq) {
				if ($seq[$i] > $SEQ[$i]) {
					my $path = "$::BASE/.net_$i";

					if (bn::fileclient::download_from $src,
					     4, $i, "$path~") {
						if ( bn::crypto::file_sigcheck
						     "$path~",
						     "xx$i"
							) {
							my $pl = plpack::load
								"$path~";

							if ($pl->("seq") >
							     $SEQ[$i]) {
								rename "$path~",
									$path;

								bn::log
									"bn::xx $src/$i: updated";

								load $i, 0;

					      # tell neighbour about new modules
								whisper $src;
								$delay = 1;

							} else {
								bn::log
									"bn::xx $src/$i: seq not higher";
							}
						} else {
							bn::log
								"bn::xx $src/$i: sigfail";
						}
					} else {
						bn::log
							"bn::xx $src/$i: unable download";
					}

					unlink "$path~";
				}
			}

			Coro::AnyEvent::sleep 5
				if $delay;
		});
};

1


=head1 NAME

Data::ID::Exim - generate Exim message IDs

=head1 SYNOPSIS

	use Data::ID::Exim qw(exim_mid);

	$mid = exim_mid;

	use Data::ID::Exim qw(exim_mid_time read_exim_mid);

	$mid_time = exim_mid_time(Time::Unix::time());
	($sec, $usec, $pid) = read_exim_mid($mid);

	use Data::ID::Exim qw(base62 read_base62);

	$digits = base62(3, $value);
	$value = read_base62($digits);


=head1 DESCRIPTION

This module supplies a function which generates IDs using the algorithm
that the Exim MTA uses to generate message IDs.  It also supplies
functions to manipulate such IDs, and the base 62 encoding in isolation.

=cut

package Data::ID::Exim;

{ use 5.006; }
use warnings;
use strict;

use Carp qw(croak);
use Time::HiRes 1.00 qw(gettimeofday);

our $VERSION = "0.007";

use parent "Exporter";
our @EXPORT_OK = qw(exim_mid exim_mid_time read_exim_mid base62 read_base62);

{
	my(%base62, %read_base62);
	for(my $v = 10; $v--; ) {
		my $d = chr(ord("0") + $v);
		$base62{$v} = $d;
		$read_base62{$d} = $v;
	}
	for(my $i = 26; $i--; ) {
		{
			my $v = 10 + $i;
			my $d = chr(ord("A") + $i);
			$base62{$v} = $d;
			$read_base62{$d} = $v;
		}
		{
			my $v = 36 + $i;
			my $d = chr(ord("a") + $i);
			$base62{$v} = $d;
			$read_base62{$d} = $v;
		}
	}

	sub base62($$) {
		my($ndigits, $value) = @_;
		my $digits = "";
		while($ndigits--) {
			use integer;
			$digits .= $base62{$value % 62};
			$value /= 62;
		}
		return scalar(reverse($digits));
	}

	sub read_base62($) {
		my($digits) = @_;
		my $value = 0;
		while($digits =~ /(.)/sg) {
			$value = 62 * $value + $read_base62{$1};
		}
		return $value;
	}
}

=head1 FUNCTIONS

=over

=item exim_mid

Generates an Exim message ID.  (This ID may, of course, be used to label
things other than mail messages, but Exim refers to them as message IDs.)
The ID is based on the time and process ID, such that it is guaranteed
to be unique among IDs generated by this algorithm on this host.
This function is completely interoperable with Exim, in the sense that
it uses exactly the same algorithm so that the uniqueness guarantee
applies between IDs generated by this function and by Exim itself.

The format of the message ID is three groups of base 62 digits, separated
by hyphens.  The first group, of six digits, gives the integral number of
seconds since the epoch.  The second group, also of six digits, gives the
process ID.  The third group, of two digits, gives the fractional part
of the number of seconds since the epoch, in units of 1/2000 of a second
(500 us).  The function does not return until the clock has advanced far
enough that another call would generate a different ID.

The strange structure of the ID comes from compatibility with earlier
versions of Exim, in which the last two digits were a sequence number.

=item exim_mid(HOST_NUMBER)

Exim has limited support for making message IDs unique among a group
of hosts.  Each host is assigned a number in the range 0 to 16 inclusive.
The last two digits of the message IDs give the host number multiplied by
200 plus the fractional part of the number of seconds since the epoch in
units of 1/200 of a second (5 ms).  This makes message IDs unique across
the group of hosts, at the expense of generation rate.

To generate this style of ID, pass the host number to C<exim_mid>.
The host number must be configured by some out-of-band mechanism.

=cut

sub _make_fraction($$) {
	use integer;
	my($host_number, $usec) = @_;
	defined($host_number) ?
		200*$host_number + $usec/5000 :
		$usec/500;
}

sub exim_mid(;$) {
	my($host_number) = @_;
	my($sec, $usec) = gettimeofday;
	my $frac = _make_fraction($host_number, $usec);
	my($new_sec, $new_usec, $new_frac);
	do {
		($new_sec, $new_usec) = gettimeofday;
		$new_frac = _make_fraction($host_number, $new_usec);
	} while($new_sec == $sec && $new_frac == $frac);
	return base62(6, $sec)."-".base62(6, $$)."-".base62(2, $frac);
}

=item exim_mid_time(TIME)

Because the first section of an Exim message ID encodes the time to a
resolution of a second, these IDs sort in a useful way.  For the purposes
of lexical comparison using this feature, it is sometimes useful to
construct a string encoding a specified time in Exim message ID format.
(This can also be used as a very concise clock display.)

This function constructs the initial time portion of an Exim message
ID.  TIME must be an integral Unix time number.  The corresponding
six-base62-digit string is returned.

=cut

sub exim_mid_time($) {
	my($t) = @_;
	return base62(6, $t);
}

=item read_exim_mid(MID)

This function extracts the information encoded in an Exim message ID.
This is a slightly naughty thing to do: the ID should really only be
used as a unique identifier.  Nevertheless, the time encoded in an ID
is sometimes useful.

The function returns a three-element list.  The first two elements encode
the time at which the ID was generated, as a (seconds, microseconds)
pair giving the time since the epoch.  This is the same time format as
is returned by C<gettimeofday>.  The message ID does not encode the time
with a resolution as great as a microsecond; the returned microseconds
value is rounded down appropriately.  The third item in the result list
is the encoded PID.

=item read_exim_mid(MID, HOST_NUMBER_P)

The optional HOST_NUMBER_P argument is a truth value indicating whether the
message ID was encoded using the variant algorithm that includes a host
number in the ID.  It is essential to decode the ID using the correct
algorithm.  The host number, if present, is returned as a fourth item
in the result list.

=cut

sub read_exim_mid($;$) {
	my($mid, $host_number_p) = @_;
	croak "malformed message ID"
		unless $mid =~ /\A([0-9A-Za-z]{6})-([0-9A-Za-z]{6})-
				([0-9A-Za-z]{2})\z/x;
	my($sec, $pid, $frac) = map { read_base62($_) } ($1, $2, $3);
	if($host_number_p) {
		use integer;
		my $host_number = $frac / 200;
		my $usec = ($frac % 200) * 5000;
		return ($sec, $usec, $pid, $host_number);
	} else {
		my $usec = $frac * 500;
		return ($sec, $usec, $pid);
	}
}

=item base62(NDIGITS, VALUE)

This performs base 62 encoding.  VALUE and NDIGITS must both be
non-negative native integers.  VALUE is expressed in base 62, and the
least significant NDIGITS digits are returned as a string.

=item read_base62(DIGITS)

This performs base 62 decoding.  DIGITS must be a string of base 62
digits.  It is interpreted and the value returned as a native integer.

=back

=head1 BUGS

Can theoretically generate duplicate message IDs during a leap second.
Exim suffers the same problem.

=head1 SEE ALSO

L<Data::ID::Maildir>,
L<UUID>,
L<Win32::Guidgen>,
L<http://www.exim.org>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2004, 2006, 2007, 2009, 2010
Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

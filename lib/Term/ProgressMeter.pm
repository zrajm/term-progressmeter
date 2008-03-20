package Term::ProgressMeter;

use 5.008008;
use strict;
use warnings;
use Carp;
use Time::HiRes 'alarm';                        # progress bar needs this

our $VERSION = '0.01';

# FIXME: under which conditions should the progress bar be erased?
# (if stdout is redirected to file, and stderr is not, then there's no
# reason to erase it)

=head1 NAME

Term::ProgressMeter - Display progress meter at specified intervals

=head1 SYNOPSIS

  use Term::ProgressMeter;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Term::ProgressMeter, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=cut



###############################################################################
##                                                                           ##
##  Default Settings                                                         ##
##                                                                           ##
###############################################################################


sub TRUE()  {  1 }
sub FALSE() { '' }
our %opt = (                                    # defaults
    update_interval => .1,                      #   in seconds
    now_visible     => FALSE,                   #
    outhandle       => *STDERR,                 #
    term_width      => 50,                      #
    current_value   => '',                      #   reference to value
    max_value       => '',                      #   reference to value
    start_time      => 0,                       #
);                                              #



###############################################################################
##                                                                           ##
##  Internal Functions                                                       ##
##                                                                           ##
###############################################################################


sub _term_width {
    eval { require Term::ReadKey };
    # If GetTerminalSize() fails it should (according to its
    # docs) return an empty list. It doesn't---that's why we
    # have the eval {}---but also it may appear to succeed and
    # return a width of zero.
    my $width;
    eval {
	$width = (Term::ReadKey::GetTerminalSize($opt{outhandle}))[0];
	if ($^O eq 'MSWin32') { $width-- }
    } unless $@;
    if (!defined($width) or !$width) {
	$@ = "Term::ReadKey::GetTerminalSize returned zero\n";
    };
    if ($@) {
	carp "Cannot detect terminal width: Using $width chars\n" . "$@";
    } else {
	$opt{term_width} = $width;
    }
}

our @prev_time = ();
sub estimate_time {
    my ($new_value, $length) = @_;
    push @prev_time, $new_value;
    shift @prev_time
	while @prev_time > $length;
    my $sum  = 0;
    $sum += $_ foreach @prev_time;
    return $sum / @prev_time;
}

# show the two largest units, first one unformatted, second zero
# padded and formatted according to it's width (days = 1 digit,
# all other 2 digits)
#
# last digit is rounded
sub pretty_time {
    my ($secs) = @_;
    my %unit = qw(s 1  m 60  h 3600  d 86400  w 604800);
    my %form = qw(s 02 m 02  h 02    d 01     w 1); # sprintf format
    my ($time, $last) = ('', FALSE);
    foreach (qw/w d h m s/) {
	my $last  = TRUE if $_ eq 's';
	my $value = int($secs/$unit{$_} + ($last?.5:0));
	if ($value or $last) {
	    $time .= sprintf "%". ($time?$form{$_}:"") . "u$_", $value;
	    last if $last;
	    $secs -= $value * $unit{$_};
	    $last  = TRUE;
	}
    }
    return $time;
}


# return progress bar string
sub meter {
    my $cur = ref($opt{current_value}) eq 'SCALAR' ? ${$opt{current_value}} : 0;
    my $max = ref($opt{max_value})     eq 'SCALAR' ? ${$opt{max_value}}     : 0;

    # percentage
    my $part   = $cur / $max;                   #     float: 0..1 (start..end)
    my $prefix =                                #     pretty-print prefix
	sprintf(' %5.2f%% [', $part*100);

    # E.T.A.
    my $elapsed = time-$opt{start_time};        #     seconds since start
    my $time = $part ?                          #     total time (approx)
	($elapsed / $part) : 0;                 #
    $time  = estimate_time($time, 10);          #     do mean of last times
    $time -= $elapsed;                          #     subtract elapsed time
    my $postfix = "] " . pretty_time($time);

    # bar
    my $width = $opt{term_width} -
	(length($prefix.$postfix) + 1);
    my $barlen  = int($part * $width + .5);
  ( my $bar     = "=" x $barlen ) =~ s/=$/>/;
    my $empty   = " " x ($width-$barlen);
    return $prefix.$bar.$empty.$postfix;
}



###############################################################################
##                                                                           ##
##  User-Callable Functions                                                  ##
##                                                                           ##
###############################################################################


sub show {                                      # show progress meter
    my $fh = $opt{outhandle};                   #   filehandle
    print $fh meter() . "\e[K\r";               #   draw progress meter
    $opt{now_visible} = TRUE;                   #   note that it's visible
    start();                                    #   call next bar soon
}                                               #
sub hide {                                      # hide progress meter
    return unless $opt{now_visible};            #   do nada if not visible
    my $fh = $opt{outhandle};                   #   filehandle
    print $fh meter() . "\r\e[K";               #   erase visible progress bar
    $opt{now_visible} = FALSE;                  #   note that it's not visible
}                                               #
sub start   { alarm $opt{update_interval} }     # call next progress bar soon
sub pause   { alarm 0                     }     # stop, but don't hide
sub stop    { pause; hide                 }     # stop and hide progress bar
sub restart {                                   # reset time & restart
    $opt{start_time} = time();
    @prev_time = ();
    start;
}
sub set {                                       # change settings and restart
    my %hash = @_;
    foreach (keys %hash) {
	if (!exists $opt{$_}) {
	    carp "Unknown Term::ProgressMeter setting `$_'\n";
	    next;
	}
	$opt{$_} = $hash{$_};
    }
    restart;
}







_term_width();
%SIG = (
    INT   => sub { hide(); exit 255 },          # on kill 
    TERM  => sub { hide(); exit 255 },          # on ^C
    WINCH => sub { _term_width()    },          # on window resize
    ALRM  => sub { show()           },          # each update interval
);

1;
__END__

=head1 SEE ALSO


I found the following guide on how to make Perl modules very helpful
when writing this:

http://world.std.com/~swmcd/steven/perl/module_mechanics.html

My tiny page of programs will probably contain this module (and do
contain some other interesting tidbits and programs):

http://www.update.uu.se/~zrajm/programs/


=head1 AUTHOR

Zrajm C Akfohg, E<lt>term-progressmeter-mail@klingonska.orgE<gt>.
Suggestions are much welcome, and, as long as any changes are good and
sound, and don't break backward compatibility, sending me modified
sources is the quickest way to get your suggestions included. :) Don't
forget to include tests, if you write new code! (Come to think of it,
improved tests for my own code would also be greatly appreciated.)

I'm pretty new to the object-oriented Perl game, as well as to unit
testing, so suggestions for improvement in those two areas are
especially welcome!


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Zrajm C Akfohg.

This Perl module is published under a Creative Commons
Attribution-Share Alike 3.0 license. See:
[http://creativecommons.org/licenses/by-sa/3.0/]

=cut

#[eof]

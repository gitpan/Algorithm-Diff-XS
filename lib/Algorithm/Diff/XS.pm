package Algorithm::Diff::XS;
use 5.006;
use strict;
use warnings;
use vars '$VERSION';
use Algorithm::Diff;

BEGIN {
    $VERSION = '0.01';
    require XSLoader;
    XSLoader::load(__PACKAGE__, $VERSION);

    no warnings 'redefine';
    my $lcs;
    *Algorithm::Diff::LCSidx = sub {
        $lcs ||= Algorithm::Diff::XS->CREATE;
        my (@l, @r);
        for ( $lcs->LCS(@_) ) {
            push @l, $_->[0];
            push @r, $_->[1];
        }
        return(\@l, \@r);
    };
}

sub new {
    no warnings 'once';
    my $class = shift;
    unshift @_, 'Algorithm::Diff';
    goto &Algorithm::Diff::new;
}

sub import {
    no warnings 'once';
    my $class = shift;
    unshift @_, 'Algorithm::Diff';
    goto &Algorithm::Diff::import;
}

# Simply forward to Algorithm::Diff
sub AUTOLOAD {
    use vars '$AUTOLOAD';
    $AUTOLOAD =~ s/^Algorithm::Diff::XS/Algorithm::Diff/;
    goto &$AUTOLOAD;
}

sub line_map {
    my $ctx = shift;
    my %lines;
    push @{ $lines{$_[$_]} }, $_ for 0..$#_; # values MUST be SvIOK
    \%lines;
}

sub callback {
    my ($ctx, @b) = @_;
    my $h = $ctx->line_map(@b);
    sub { @_ ? _core_loop($ctx, $_[0], 0, $#{$_[0]}, $h) : @b }
}

sub LCS {
    my ($ctx, $a, $b) = @_;
    my ($amin, $amax, $bmin, $bmax) = (0, $#$a, 0, $#$b);

    while ($amin <= $amax and $bmin <= $bmax and $a->[$amin] eq $b->[$bmin]) {
        $amin++;
        $bmin++;
    }
    while ($amin <= $amax and $bmin <= $bmax and $a->[$amax] eq $b->[$bmax]) {
        $amax--;
        $bmax--;
    }

    my $h = $ctx->line_map(@$b[$bmin..$bmax]); # line numbers are off by $bmin

    return $amin + _core_loop($ctx, $a, $amin, $amax, $h) + ($#$a - $amax)
        unless wantarray;

    my @lcs = _core_loop($ctx,$a,$amin,$amax,$h);
    if ($bmin > 0) {
        $_->[1] += $bmin for @lcs; # correct line numbers
    }

    map([$_ => $_], 0 .. ($amin-1)),
        @lcs,
            map([$_ => ++$bmax], ($amax+1) .. $#$a);
}


1;

__END__

=head1 NAME

Algorithm::Diff::XS - Algorithm::Diff with XS core loop

=head1 SYNOPSIS

    # Drop-in replacement to Algorithm::Diff, but ~50x faster
    use Algorithm::Diff::XS qw( ... );
    Algorithm::Diff::XS->new( ... );

=head1 DESCRIPTION

This module is a simple re-packaging of Joe Schaefer'S excellent
but not very well-known L<Algorithm::LCS> with a drop-in interface
that simply re-uses the L<Algorithm::Diff> module.

=head1 SEE ALSO

L<Algorithm::Diff>, L<Algorithm::LCS>.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2008 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

Contains derived code copyrighted 2003 by Joe Schaefer,
 E<lt>joe+cpan@sunstarsys.comE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

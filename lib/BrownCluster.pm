package BrownCluster;
use strict;
use warnings;
use utf8;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
use Exporter;
$VERSION     = 1.0.0;
@ISA = qw(Exporter);
@EXPORT      = qw();
@EXPORT_OK   = qw/full_bitstring short_4bitstring short_6bitstring/;
%EXPORT_TAGS = ( );

my $CLUSTER_DATA = '../data/brown_cluster.dat';

my ($data, $data_4bit, $data_6bit); 

sub full_bitstring {
    my ($word) = @_;

    if (!defined $data) {
        ($data, $data_4bit, $data_6bit) = read_cluster($CLUSTER_DATA);
    }
    
    my $wc = $data->{$word};
    
    return $wc;
}

sub short_4bitstring {
    my ($word) = @_;

    if (!defined $data_4bit) {
        ($data, $data_4bit, $data_6bit) = read_cluster($CLUSTER_DATA);
    }
    
    my $wc = $data_4bit->{$word};
    
    return $wc;
}

sub short_6bitstring {
    my ($word) = @_;

    if (!defined $data_6bit) {
        ($data, $data_4bit, $data_6bit) = read_cluster($CLUSTER_DATA);
    }
    
    my $wc = $data_6bit->{$word};
    
    return $wc;
}

sub short_bitstring {
    my ($word, $n) = @_;
    my $full_bitstring = full_bitstring($word);

    if ( !defined $full_bitstring ) {
        return undef;
    }

    return _short_bitstring($full_bitstring, $n);
}

sub _short_bitstring {
    my ($fullstring, $n) = @_;

    if ( length($fullstring) < $n ) {
        return undef;
    }
    else {
        return substr($fullstring, 0, $n);
    }
}

sub read_cluster {
    my ($filename) = @_;

    my $cluster = {};
    my $cluster_4bit = {};
    my $cluster_6bit = {};
    open FIN, '<:encoding(UTF-8)', $filename
        or die "ERROR reding $filename";

    while (my $line = <FIN>) {
        chomp($line);
        next if $line eq '';
        my ($full_string, $word, $freq) = split("\t", $line);
        $cluster->{$word} = $full_string;
        my $_4bit = _short_bitstring($full_string, 4);
        my $_6bit = _short_bitstring($full_string, 6);

        if ( defined $_4bit ) {
            $cluster_4bit->{$word} = $_4bit;
            $cluster_6bit->{$word} = $_6bit;
        }
    }

    close FIN;

    return ($cluster, $cluster_4bit, $cluster_6bit);
}

sub test {
    my ($got, $expected) = @_;

    if ( $got eq $expected ) {
        print " OK  Got: $got  Expected: $expected\n";
    }
    else {
        print "  X  Got: $got  Expected: $expected\n";
    }
}

__PACKAGE__->main() unless caller;

sub main {
    test( full_bitstring('industry'), '1001011010' );
    test( full_bitstring('Industry'), '0110011001000' );
    test( _short_bitstring('0110011001000', 4), '0110' );
    test( short_bitstring('Industry', 4), '0110' );
    test( short_4bitstring('Industry'), '0110' );
    test( short_6bitstring('Industry'), '011001' );

    my $bitstr = full_bitstring('industry');
    for my $str ($bitstr, 'abcdef') {
        if ($str =~ /[01]{10,}/) {
            print " OK  $str\n";
        }
        else {
            print "  X  $str\n";
        }
    }
}

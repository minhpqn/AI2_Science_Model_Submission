package ParsedDataReader;
use Sentence;
use strict;
use warnings;
use utf8;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
use Exporter;
$VERSION     = 1.0.0;
@ISA = qw(Exporter);
@EXPORT      = qw(read_parsed_data);
@EXPORT_OK   = qw(read_a_sentence);
%EXPORT_TAGS = ( );

# Date: 2016/02/01
# Module for reading one-sentence-per-line-format data
# ----------------------------------------------------
# Example parsed result for a sentence (the first column is sentence id)
# Who invented papyrus ?  who invent papyrus ?    WP VBD NN .     (ROOT (SBARQ (WHNP (WP Who)) (SQ (VP (VBD invented) (NP (NN papyrus)))) (. ?)))        0::root::2 2::nsubj::1 2::dobj::3 2::punct::4    ROOT::root::invented invented::nsubj::Who invented::dobj::papyrus invented::punct::?    0::root::2 2::nsubj::1 2::dobj::3       ROOT::root::invented invented::nsubj::Who invented::dobj::papyrus

# read a file that contains the parsed results by Stanford CoreNLP
# return an ARRAY of Sentence objects
sub read_parsed_data {
    my ( $filename ) = @_;

    my $sentences = [ ];
    open( my $fin, "<:encoding(UTF-8)", $filename )
        or die "Couldn't open file $filename to read: $!";

    while ( my $line = <$fin> ) {
        chomp($line);
        next if ( $line =~ /^[\s\t]*$/ );
        my $sent = read_a_sentence($line);
        push @$sentences, $sent;
    }
    close $fin;

    return $sentences;
}

sub read_a_sentence {
    my ( $line ) = @_;

    my @data = split("\t", $line);
    my $wordstr  = shift @data;
    my $lemmastr = shift @data;
    my $posstr   = shift @data;
    shift @data;                # parse
    my $basic_depstr   = shift @data;
    shift @data;
    my $collapsed_depstr = shift @data;
    shift @data;

    my @words = split(' ', $wordstr);
    my @lemma = split(' ', $lemmastr);
    my @pos   = split(' ', $posstr);

    my $sent = Sentence->new();
    for my $i (0..$#words) {
        my $word  = $words[$i];
        my $lemma = $lemma[$i];
        my $pos   = $pos[$i];
        
        my $tok = Token->new({
            word  => $word,
            lemma => $lemma,
            pos   => $pos,
        });

        $sent->add_token($tok);
    }

    my @triplets = split(' ', $collapsed_depstr);
    for my $tp ( @triplets ) {
        my ($gov, $rel, $dep) = split('::', $tp);
        $sent->add_triplet([$rel, $gov, $dep]);
    }
    
    return $sent;
}

1;










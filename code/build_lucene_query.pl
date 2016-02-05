use lib './lib';
use Sentence;
use File::Basename;
use Getopt::Long;
use strict;
use warnings;
use utf8;

##########################################################################
# build_lucene_query.pl
# Create Lucene query for questions and answers
# References:
# [1] Adrian Iftene. CLEF 2011. Question Answering for Machine Reading Evaluation on Romanian and English
##########################################################################

#
# History
# ----------------------------------
# 2015/11/12   start implementation
#

my $stopwords = './data/stopword.txt';
my %stopword = read_stopwords($stopwords);

sub print_line {
    print "# --------------------------------\n";
}

sub usage {
    print "usage: parsed_file\n";
    exit;
}

if ( @ARGV != 1 ) {
    usage;
}

my $parsed_file = shift @ARGV;
my $basename = basename( $parsed_file, '.elem' );

print "# Parsed data: $parsed_file\n";
print "# Basename: $basename\n";
print_line();
print "# Reading data...\n";
my $corpus = {};
my @qlist;
my %seen;
open FIN, '<:encoding(UTF-8)', $parsed_file
    or die "ERROR reading $parsed_file";
while (my $line = <FIN>) {
    chomp($line);
    next if $line eq '';
    my ($qid, $stype, $sid, @info) = split("\t", $line);
    if ( !exists $seen{$qid} ) {
        push @qlist, $qid;
        $seen{$qid} = 1;
    }

    my $s = get_sentence(\@info);
    push @{ $corpus->{$qid}{$stype} }, $s;
}
close FIN;

my $output = "./$basename.query.txt";

open FOUT, '>:encoding(UTF-8)', $output
    or die "ERROR writing $output";

my @choices = qw(A B C D);
for my $qid (@qlist) {
    my $ques = $corpus->{$qid}{Q};
    my @qkeywords = get_keywords( $ques );
    print FOUT join("\t", $qid, 'Q', join(" ", @qkeywords)),"\n";
    for my $choice (@choices) {
        my $ans = $corpus->{$qid}{$choice};
        my @ans_keywords = get_keywords( $ans );
        print FOUT join("\t", $qid, $choice, join(" ", @ans_keywords)),"\n";
    }
}

close FOUT;

print "# Output query file: $output\n";

###########################################################

# extract keywords for a list of sentences
sub get_keywords {
    my ( $textspan ) = @_;

    my %keyword;
    for my $sent ( @$textspan ) {
        my @sent_keywords = get_sent_keywords( $sent );
        @keyword{@sent_keywords} = ( );
    }
    return sort keys %keyword;
}

# extract sentences' keywords
sub get_sent_keywords {
    my ( $sent ) = @_;
    my %keyword;
    for my $tok ( $sent->tokens ) {
        next if ( is_stopword( $tok->lemma ) );
        next if ( is_special( $tok->lemma ) );
        next if ( $tok->pos eq 'CD' );
        $keyword{ $tok->lemma } = 1;
    }

    return sort keys %keyword;
}

sub is_special {
    my ( $str ) = @_;
    my @punc = (
        '.', ',', ':', '(', ')', '%', '[', ']', '!', ';', "'", '?', '"',
        "'s", '_', '>', '<', '-rrb-', '-lrb-', '-', '+', '=', "\\",
        "/", "*",
    );

    my %punc;
    @punc{@punc} = ();
    if ( exists $punc{$str} ) {
        return 1;
    }

    if ( $str =~ /^_+$/ ) {
        return 1;
    }
    return 0;
}

# Return a sentence object from a list of fields
# 100001	Q	1	When athletes begin to exercise , their heart rates and respiration rates increase .	when athlete begin to exercise , they heart rate and respiration rate increase .	WRB NNS VBP TO VB , PRP$ NN NNS CC NN NNS VBP .	(ROOT (S (SBAR (WHADVP (WRB When)) (S (NP (NNS athletes)) (VP (VBP begin) (S (VP (TO to) (VP (VB exercise))))))) (, ,) (NP (PRP$ their) (NN heart) (NNS rates) (CC and) (NN respiration) (NNS rates)) (VP (VBP increase)) (. .))) 	0::root::13 3::advmod::1 3::nsubj::2 13::advcl::3 5::mark::4 3::xcomp::5 13::punct::6 9::nmod:poss::7 9::compound::8 13::nsubj::9 9::cc::10 12::compound::11 9::conj::12 13::punct::14	ROOT::root::increase begin::advmod::When begin::nsubj::athletes increase::advcl::begin exercise::mark::to begin::xcomp::exercise increase::punct::, rates::nmod:poss::their rates::compound::heart increase::nsubj::rates rates::cc::and rates::compound::respiration rates::conj::rates increase::punct::.	0::root::13 3::advmod::1 3::nsubj::2 13::advcl::3 5::mark::4 3::xcomp::5 13::punct::6 9::nmod:poss::7 9::compound::8 13::nsubj::9 9::cc::10 12::compound::11 9::conj:and::12 13::punct::14	ROOT::root::increase begin::advmod::When begin::nsubj::athletes increase::advcl::begin exercise::mark::to begin::xcomp::exercise increase::punct::, rates::nmod:poss::their rates::compound::heart increase::nsubj::rates rates::cc::and rates::compound::respiration rates::conj:and::rates increase::punct::.
sub get_sentence {
    my ($fields) = @_;
    my @data = @$fields;

    my $wordstr  = shift @data;
    my $lemmastr = shift @data;
    my $posstr   = shift @data;
    shift @data; # parse
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

sub is_stopword {
    my ($word) = @_;
    
    if ( exists $stopword{$word} ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub read_stopwords {
    my ($filename) = @_;
    open FIN, '<:encoding(UTF-8)', $filename or die '';
    chomp( my @lines = <FIN> );
    @lines = grep { $_ ne '' } @lines;
    close FIN;
    my %stopword;
    @stopword{@lines} = ( );

    return %stopword;
}















package XML2Simple;
use Getopt::Long;
use XML::libXML;
use Data::Dumper;
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';

# xml2simple.pl
# Convert stanford-corenlp's parsed corpus into simple format
# Each line contains parsed content of one sentence

__PACKAGE__->main() unless caller;

sub usage {
    print {*STDERR} "usage: input\n";
    exit;
}

sub main {
    if (@ARGV != 1) {
        usage();
    }

    my $xmlfile = shift @ARGV;
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_file($xmlfile)
        or die "Error reading $xmlfile\n";

    my @examples = $doc->getElementsByTagName('example');

    for my $exmp (@examples) {
        my $exmp_id = $exmp->getAttribute('id');
        my $exmp_ans = $exmp->getAttribute('answer');

        my $ques = $exmp->getChildrenByTagName('question')->[0];
        my @qsentences = get_sentences($ques);

        for my $i (0..$#qsentences) {
            my $qsent = $qsentences[$i];
            my $row = join("\t", $exmp_id, 'Q', $i+1, $qsent);
            print "$row\n";
        }

        my @answer_nodes = $exmp->getChildrenByTagName('answer');
        for my $answer_node (@answer_nodes) {
            my $answer_id = $answer_node->getAttribute('id');
            my @answer_sentences = get_sentences($answer_node);
            for my $i (0..$#answer_sentences) {
                my $sent = $answer_sentences[$i];
                my $row = join("\t", $exmp_id, $answer_id, $i+1, $sent);
                print "$row\n";
            }
        }
    }
}

# Return information about dependencies given a Node
sub get_dep_info {
    my ($dep_root_node) = @_;

    my @dep_nodes = $dep_root_node->getChildrenByTagName('dep');
    my @dep_id;
    my @dep_text;
    for my $dep_node (@dep_nodes) {
        my $type = $dep_node->getAttribute('type');
        my $gov_node = $dep_node->getChildrenByTagName('governor')->[0];
        my $gov_id = $gov_node->getAttribute('idx');
        my $gov_txt = $gov_node->textContent;
            
        my $dependent_node =
            $dep_node->getChildrenByTagName('dependent')->[0];
        my $dep_id = $dependent_node->getAttribute('idx');
        my $dep_txt = $dependent_node->textContent;

        my $depid = join("::", $gov_id, $type, $dep_id);
        my $deptxt = join("::", $gov_txt, $type, $dep_txt);
        push @dep_id, $depid;
        push @dep_text, $deptxt;
    }

    my $dep_id = join(" ", @dep_id);
    my $dep_text = join(" ", @dep_text);

    return join("\t", $dep_id, $dep_text);
}

sub get_sentences {
    my ($start_node) = @_;

    my $txt_node = $start_node->getChildrenByTagName('text')->[0];
    my $sentences_node = $start_node->getChildrenByTagName('sentences')->[0];
    
    my @sentences;    
    my @sentence_nodes = $sentences_node->getChildrenByTagName('sentence');
    for my $sent_node (@sentence_nodes) {
        my $sent = get_a_sentence( $sent_node );
        push @sentences, $sent;
    }
    return @sentences;
}

sub get_a_sentence {
    my ( $sent_node ) = @_;

    my @data;
    my $tokens_node = $sent_node->getChildrenByTagName('tokens')->[0];
    my @token_nodes = $tokens_node->getChildrenByTagName('token');
    my @tokens;
    for my $tok_node (@token_nodes) {
        my $tok = {};
        my $tok_id = $tok_node->getAttribute('id');
        $tok->{id} = $tok_id;
        for my $tag ( qw(word lemma POS) ) {
            my $node = $tok_node->getChildrenByTagName($tag)->[0];
            my $text = $node->textContent;
            $tok->{$tag} = $text;
        }
        push @tokens, $tok;
    }
    my $surf = join(' ', map { $_->{word} } @tokens);
    my $lemma = join(' ', map { $_->{lemma} } @tokens);
    my $pos = join(' ', map { $_->{POS} } @tokens);
    push @data, ($surf, $lemma, $pos);

    my $parse_node = $sent_node->getChildrenByTagName('parse')->[0];
    my $parse_tree = $parse_node->textContent;
    push @data, $parse_tree;

    my @dependencies_nodes =
        $sent_node->getChildrenByTagName('dependencies');
    my $basic_dep = $dependencies_nodes[0];
    my $collapsed_dep = $dependencies_nodes[1];

    my $basic_dep_info = get_dep_info($basic_dep);
    my $collapsed_dep_info = get_dep_info($collapsed_dep);

    push @data, $basic_dep_info;
    push @data, $collapsed_dep_info;

    my $sent = join("\t", @data);
}


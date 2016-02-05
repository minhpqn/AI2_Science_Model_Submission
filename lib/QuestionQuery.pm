package QuestionQuery;
use Sentence;
use Data::Dumper;
use strict;
use warnings;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
use Exporter;
$VERSION     = 1.0.0;
@ISA = qw(Exporter);
@EXPORT      = qw(question_query);
@EXPORT_OK   = qw/get_noun_phrases get_rel_phrases get_aux_verbs elem_surf
                  get_sentence_elements elem_to_s
                 /;
%EXPORT_TAGS = ( );

# Conversion from a question to question query using hand-written templates
# from the paper Fader. (2014). Open Question Answering Over Curated and
# Extracted Knowledge Bases

our $DEBUG = 0;

my %question_patterns = (
    '(Who|What)\sRV\sNP'      => "?x,rel,arg",
    '(Who|What)\sAUX\sNP\RV'  => "arg,rel,?x",
    '(Where|When)\sAUX\sNP\sRV' => "arg,rel in,?x",
    '',
);

sub question_query {
    my ( $sen ) = @_;

    my $ques_pattern  = '';
    my $query_pattern = '';
    my $query         = '';

    $ques_pattern = question_pattern( $sen );

    return ( $ques_pattern, $query_pattern, $query );
}

sub question_pattern {
    my ( $sen ) = @_;
    
    my $elements = get_sentence_elements( $sen );

    return '';
}

sub get_sentence_elements {
    my ( $sen ) = @_;

    my $elements = [];
    my $noun_phrases = get_noun_phrases($sen);
    my $rel_phrases  = get_rel_phrases($sen);
    my $aux_verbs    = get_aux_verbs($sen);

    my %aux  = get_indexes( $aux_verbs);
    my %np   = get_indexes( $noun_phrases );
    my %rel  = get_indexes( $rel_phrases );
    my %elem = get_indexes( [@$noun_phrases, @$rel_phrases, @$aux_verbs] );
    
    my @wh_words1 = (
        'Who', 'What',
    );
    my %wh_words1; @wh_words1{@wh_words1} = ();
    
    my @wh_words2 = (
        'Who', 'What', 'Where', 'When',
    );
    my %wh_words2; @wh_words2{@wh_words2} = ();
    
    my @tokens = $sen->tokens;
    my $i = 0;
    while ( $i < $sen->num_token() ) {
        my $tk_i = $sen->at($i);
        my $prev_word;
        $prev_word = $sen->at($i-1)->word if ( $i > 0 );

        my $elem;
        if ( !exists $elem{$i} ) {
            $elem = make_tok_elem($sen, $i);
        }
        elsif ( exists $aux{$i} ) {
            $elem = $aux{$i};
            if ( $i > 0 && exists $wh_words1{$prev_word} && is_special_aux($tk_i) ) {
                $elem = make_tok_elem($sen, $i);
            }
        }
        else {
            $elem = $elem{$i};
        }
        push @$elements, $elem;
        $i = $elem->{end};
    }
    
    return $elements;
}

sub elem_to_s {
    my ( $elem ) = @_;
    
    if ( $elem->{type} eq '' ) {
        return $elem->{surface};
    }
    elsif ( $elem->{sub_type} eq '' ) {
        return $elem->{type};
    }
    else {
        return join(":", $elem->{type}, $elem->{sub_type});
    }
}

sub is_special_aux {
    my ($tk) = @_;
    
    my @special_aux = (
        'are', 'is',
    );
    my %special_aux;
    @special_aux{@special_aux} = ();

    return exists $special_aux{$tk->word};
}

sub make_tok_elem {
    my ( $sen, $i ) = @_;
    my @tokens = $sen->tokens();
    my $elem = {
        begin    => $i,
        end      => $i+1,
        type     => '',
        sub_type => '',
        surface  => join(" " => map { $_->word }  @tokens[$i..$i]),
        base     => join(" " => map { $_->lemma } @tokens[$i..$i]),
    };
    return $elem;
}

sub get_indexes {
    my ( $phrases ) = @_;
    my %id_tbl;
    for my $elem ( @$phrases ) {
        $id_tbl{ $elem->{begin} } = $elem;
    }
    return %id_tbl;
}

sub __get_phrases_by_patterns {
    my ( $sen, $patterns, $type ) = @_;

    my $phrases = [];
    my $pos_sequence = join(" ", $sen->POS_tags());
    my %marked;
    my @tokens = $sen->tokens;
    
    for my $regx ( @$patterns ) {
      POS:
        while ( $pos_sequence =~ /$regx/g ) {
            my $l = pos($pos_sequence) - length($1);
            my $r = pos($pos_sequence);

            my $begin = get_word_index($l, $pos_sequence);
            my $end   = get_word_index($r, $pos_sequence);

            for my $i ($begin..$end-1) {
                if ( exists $marked{$i} ) {
                    next POS;
                }
                $marked{$i} = 1;
            }

            if ( $begin >= $end ) {
                next POS;
            }

            my @tok_seq = @tokens[$begin..$end-1];
            my $ph = {
                begin    => $begin,
                end      => $end,
                type     => $type,
                sub_type => '',
                surface  => join(" " => map { $_->word }  @tok_seq),
                base     => join(" " => map { $_->lemma } @tok_seq),
            };

            push @$phrases, $ph;

            if ( defined $DEBUG and $DEBUG == 1 ) {
                my $ph_str = $end > $begin ?
                    join(" ", map { $_->word } @tokens[$begin..$end-1]) : '';
                my $btk = $sen->at($begin);
                my $bw  = join("/", $btk->word, $btk->pos);
                print "'$regx'\t'$1' at position $l ~ $r (token indexes: $begin ~ $end)\t'$ph_str'\t'$bw'\n";
            }
        }
    }

    return $phrases;
}

sub get_noun_phrases {
    my ( $sen ) = @_;

    my $np_patterns = [
        '(((^DT|\sDT|PRP\$)\s)?((JJ|JJR|JJS|NN|NNS|NNP|NNPS)\s)*((NN|NNS|NNP|NNPS)\sIN)?((^DT|\sDT|JJ|JJR|JJS|POS|NN|NNS|NNP|NNPS)\s)*(NNPS|NNP|NNS|NN))',
        '(((^DT|\sDT|PRP\$)\s)?((JJ|JJR|JJS)\s)*(NNPS|NNP|NNS|NN))',
        '(((NNPS|NNP)\s)+)',
        '((NN\s)+|(NN\s)*NN$)',
    ];

    my $noun_phrases = __get_phrases_by_patterns( $sen, $np_patterns, 'NP' );
    return $noun_phrases;
}

sub get_rel_phrases {
    my ( $sen ) = @_;

    # $DEBUG = 1;
    # use REVERB patterns
    my $V = '(VBZ|VBP|VBN|VBG|VBD|VB)(\sRP)?(\sRBS|RBR|RB)?';
    my $W = '(NNPS|NNP|NNS|NN|JJS|JJR|JJ|RBS|RBR|RB|PRP|DT)';
    my $P = '(IN|RP|TO)';

    my $vp_patterns = [
        '((VBZ|VBP|VBN|VBG|VBD|VB)(\sRP)?(\sRBS|RBR|RB)?(\s(NNPS|NNP|NNS|NN|JJS|JJR|JJ|RBS|RBR|RB|PRP|DT))*\s(IN|RP|TO))',
        '((VBZ|VBP|VBN|VBG|VBD|VB)(\sRP)?(\sRBS|RBR|RB)?\s(IN|RP|TO))',
        '((VBZ|VBP|VBN|VBG|VBD|VB)(\sRP)?(\sRBS|RBR|RB)?)',
    ];

    my $rel_phrases = __get_phrases_by_patterns( $sen, $vp_patterns, 'RV' );

    return $rel_phrases;
}

sub get_aux_verbs {
    my ( $sen ) = @_;
    
    my $aux_verbs = [];

    my %aux_id;
    for my $tpl ( $sen->triplets ) {
        my $rel = $tpl->[0];
        my $dep = $tpl->[2];
        if ( $rel eq 'aux' or $rel eq 'auxpass' ) {
            $aux_id{$dep} = 1;
        }
    }

    my @aux_id = sort { $a<=>$b } keys %aux_id;
    return [] if ( @aux_id == 0 );
        
    my @streak;
    my $i = 0;
    my $j = $i;
    while ( $j < $#aux_id ) {
        if ( $aux_id[$j+1] != $aux_id[$j] + 1 ) {
            push @streak, [$i, $j];
            $i = $j+1;
        }
        $j++;
    }
    push @streak, [$i, $j];

    my @tokens = $sen->tokens;
    for my $pair ( @streak ) {
        my ($i, $j) = @$pair;
        my $begin = $aux_id[$i] - 1;
        my $end   = $aux_id[$j];
        my @tok_seq = @tokens[$begin..$end-1];
        my $ph = {
            begin    => $begin,
            end      => $end,
            type     => 'AUX',
            sub_type => '',
            surface  => join(" " => map { $_->word }  @tok_seq),
            base     => join(" " => map { $_->lemma } @tok_seq),
        };
        push @$aux_verbs, $ph;
    }

    # $DEBUG = 1;
    if ( $DEBUG ) {
        my $wp  = join(" ", $sen->word_pos_pairs);
        my @aux = map { add_quote($sen->token_at($_)->word) } @aux_id;
        my $line = join("\t", $wp, @aux);
        print "$line\n";
    }
    
    return $aux_verbs;
}

sub add_quote {
    my ( $word ) = @_;
    return "'$word'";
}

sub get_word_index {
    my ( $id, $pos_sequence ) = @_;

    my $i = $id;
    if ( substr($pos_sequence, $id, 1) eq ' ' ) {
        ++$i;
    }
    
    my $sub_string = substr($pos_sequence, 0, $i + 1);
    my $num_tok = split(" ", $sub_string);

    return $num_tok - 1;
}

sub elem_surf {
    my ( $elem ) = @_;

    my $str = $elem->{surface};

    return $str;
}


1;

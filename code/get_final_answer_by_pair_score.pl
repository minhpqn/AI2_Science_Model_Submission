package PairScoreIR;
use Getopt::Long;
use File::Basename;
use Data::Dumper;
use List::Util qw( max min );
use POSIX qw( ceil );
use Encode qw( decode );
use Lucy::Search::IndexSearcher;
use Lucy::Highlight::Highlighter;
use Lucy::Search::QueryParser;
use Lucy::Search::TermQuery;
use Lucy::Search::ANDQuery;
use Lucy::Index::Similarity;
use strict;
use warnings;
use utf8;
binmode STDOUT, ":utf8";

# get_final_answer_by_pair_score.pl
# Description:
# - Rank choices by top N documents' scores returned by pairs of (ques, choice)
# - Choose the choice with the highest score

srand 19840209;

__PACKAGE__->main() unless caller;

sub usage {
    print "usage: [Options] query_file\n";
    print "  [Options]\n";
    print "     --output  output_file\n";
    print "     --gold_data gold_data_file\n";
    print "     --page_size <page_size>\n";
    print "       (Number of relevant documents to be retrieved\n";
    print "        default=10)\n";
    print "     --index indexDirectory\n";
    print "     --avg\n";
    print "       Use average score over all relevant documents\n";
    print "     --help\n";
    exit;
}

sub main {
    my $page_size = 10;
    my $path_to_index;
    my $output_file;
    my $score_file;
    my $gold_data_file;
    my $avg;
    my $help;

    GetOptions(
        "output=s"    => \$output_file,
        "page_size=i" => \$page_size,
        "index=s"     => \$path_to_index,
        "avg"         => \$avg,
        "gold_data=s"   => \$gold_data_file,
        "help"        => \$help,
    );

    if ( $help ) {
        usage();
    }

    if ( !defined $path_to_index ) {
        print {*STDERR} ";;; path_to_index is missing\n";
        usage();
    }

    if ( @ARGV < 1 ) {
        usage();
    }

    my $query_file  = shift @ARGV;
    my $basename = basename($query_file, 'query.txt');

    print "# Index file: $path_to_index\n";
    print "# Page size = $page_size\n";
    print "# Query file: $query_file\n";
    if ( defined $output_file ) {
        $score_file = "./$output_file.score.txt";
        print "# Result file: $output_file\n";
        print "# Score file: $score_file\n";
    }

    my ( $queries, $qlist ) = load_queries( $query_file );
    my ( $result, $score_hsh ) =
        get_final_answers_by_pair_score( $queries, $path_to_index, $page_size, $avg );

    # Evaluation on training set
    if ( defined $gold_data_file ) {
        evaluation( $gold_data_file, $result );
    }

    if ( defined $output_file ) {
        # write submission file
        open FOUT1, '>', $output_file
            or die "ERROR writing $output_file";
        open FOUT2, '>', $score_file
            or die "ERROR writing $score_file";

        print FOUT1 "id,correctAnswer\n";

        for my $qid ( @$qlist ) {
            my $final_answer = $result->{$qid};
            print FOUT1 join(",", $qid, $final_answer),"\n";

            my @choices = qw(A B C D);
            for my $choice ( @choices ) {
                my $tot_score = $score_hsh->{$qid}{$choice};
                print FOUT2 join("\t", $qid, $choice, $tot_score),"\n";
            }
        }

        close FOUT1;
        close FOUT2;
    }
}

sub get_final_answers_by_pair_score {
    my ( $queries, $path_to_index, $page_size, $avg_opt ) = @_;

    my $result    = {};
    my $score_hsh = {};
    my @qid = keys %$queries;

    my $avg = 0;
    if ( defined $avg_opt && $avg_opt ) {
        $avg = 1;
    }

    my @choices = qw(A B C D);

    my $searcher = Lucy::Search::IndexSearcher->new( 
        index  => $path_to_index,
    );
    my $qparser = Lucy::Search::QueryParser->new( 
        schema => $searcher->get_schema,
    );
    
    my $count = 0;
    for my $qid ( @qid ) {
        $count++;
        if ( $count % 100 == 0 ) {
            print {*STDERR} ".";
        }
        if ( $count % 1000 == 0 ) {
            print {*STDERR} "$count";
        }
    
        my $ques_query = $queries->{$qid}{Q};
        my @ques_terms = split(" ", $ques_query);

        my %score;
        for my $ch ( @choices ) {
            my $ch_query = $queries->{$qid}{$ch};
            my @ch_terms = split(" ", $ch_query);
            my %terms;
            @terms{@ques_terms} = ( );
            @terms{@ch_terms} = ( );
            my $query_str = join(" ", sort keys %terms);

            # Build up a Query.
            my $query = $qparser->parse($query_str);

            # Execute the Query and get a Hits object.
            my $hits = $searcher->hits(
                query      => $query,
                num_wanted => $page_size,
            );

            my $tot_score = 0;
            my $num_docs  = 0;
          HIT:
            while ( my $hit = $hits->next ) {
                $num_docs++;
                $tot_score += $hit->get_score;
            }
            
            if ( $avg ) {
                $tot_score = $num_docs == 0 ? 0 : $tot_score/$num_docs;
            }

            $score{$tot_score}{$ch} = 1;
            $score_hsh->{$qid}{$ch} = $tot_score;
        }

        my @sorted = sort { $b<=>$a } keys %score;
        my @top = sort keys %{ $score{$sorted[0]} };
        my $final_answer;
        if ( @top == 1 ) {
            $final_answer = shift @top;
        }
        else {
            # randomly select the answer
            $final_answer = $top[rand @top];
        }

        $result->{$qid} = $final_answer;
    }
    
    print {*STDERR} "\nFinished!\n";

    return ( $result, $score_hsh );
}

sub print_line {
    print "# --------------------------------\n";
}

sub load_queries {
    my ( $query_file ) = @_;
    open( my $fh, '<:encoding(UTF-8)', $query_file )
        or die "ERROR reading $query_file";

    my $queries;
    my $qlist;
    my %seen;
    while (my $line = <$fh>) {
        chomp($line);
        next if $line eq '';
        my ($qid, $stype, $query) = split("\t", $line);
        if ( !exists $seen{$qid} ) {
            push @$qlist, $qid;
            $seen{$qid} = 1;
        }
        $queries->{$qid}{$stype} = $query;
    }
    close $fh;

    return ( $queries, $qlist );
}

sub evaluation {
    my ( $gold_data_file, $result ) = @_;

    my $gold_label = get_gold_labels( $gold_data_file );

    my ( $acc, $ncorrect, $ntotal ) = _eval( $gold_label, $result );
    printf( "# Training accuracy = %4.2f ( $ncorrect/$ntotal )\n", $acc );
}

sub _eval {
    my ( $gold_label, $result ) = @_;

    my $ncorrect = 0;
    my $ntotal = 0;
    for my $qid ( keys %$result ) {
        my $ans = $result->{$qid};
        if ( !defined $gold_label->{$qid}{$ans} ) {
            die "$qid  $ans";
        }
        if ( $gold_label->{$qid}{$ans} eq 'O' ) {
            $ncorrect++;
        }
        $ntotal++;
    }
    my $acc = 100 * $ncorrect / $ntotal;

    return ( $acc, $ncorrect, $ntotal );
}

sub get_gold_labels {
    my ( $training_tag ) = @_;
    my $label_hsh;
    open FIN, '<', $training_tag
        or die "ERROR reading $training_tag";
    my $line = <FIN>;
    while ($line = <FIN>) {
        chomp($line);
        next if $line =~ /^[\s\t]*$/;
        my ( $qid, $q, $correctAnswer ) = split("\t", $line);
        for my $choice ( qw(A B C D) ) {
            my $label = 'X';
            if ( $choice eq $correctAnswer ) {
                $label = 'O';
            }
            $label_hsh->{$qid}{$choice} = $label;
        }
    }
    close FIN;

    return $label_hsh;
}







require './code/xml2simple.pl';
use File::Path qw/mkpath/;
use File::Basename;
use Carp qw/confess/;
use Getopt::Long;
use strict;
use warnings;

# Process .xml files one by one and convert to a combined .elem file
# Do not need to make a big .xml file

main();

sub _usage {
    print "usage: [Options] datafile tmpdir\n";
    print " [Options]\n";
    print "   --without_parsing\n";
    print "   --validation\n";
    exit;
}

sub main {
    my $validation;
    my $without_parsing;
    GetOptions(
        "without_parsing" => \$without_parsing,
        "validation"      => \$validation,
    );
    $validation = 0 unless ($validation);

    if (@ARGV != 2) {
        _usage();
    }

    my $datafile = shift @ARGV;
    my $tmpdir = shift @ARGV;

    my $basename = basename($datafile, '.tsv');
    my $workdir = join("/", $tmpdir, $basename);

    if (!-d $workdir) {
        mkpath($workdir);
    }
    
    my $file_list = "$workdir/list.txt";
    if ( !$without_parsing ) {
        get_list_file($datafile, $workdir, $file_list, $validation);
        run_stanford_corenlp( {filelist => $file_list,
                               outputDirectory => $workdir} );
    }
    combine_parsed_results($datafile, $workdir, $validation);
}

# Combine results parsed by stanford-corenlp into one .elem file
sub combine_parsed_results {
    my ($datafile, $workdir, $validation) = @_;

    my @chars = qw(A B C D);
    open FI, '<', $datafile or die "Error reading $datafile";
    while (my $line = <FI>) {
        chomp($line);
        next if $line =~ /^id/;

        my ($id, $q, $gold, @answers);
        if ($validation) {
            ($id, $q, @answers) = split("\t", $line);
        }
        else {
            ($id, $q, $gold, @answers) = split("\t", $line); 
        }

        $gold = 'X' if (!defined $gold);
        
        my $qsentences = get_sentences("$workdir/$id.txt.xml");
        print_sentences( $id, 'Q', $qsentences);
        
        for my $i (0..$#chars) {
            my $sentences = get_sentences("$workdir/$id\_$chars[$i].txt.xml");
            print_sentences( $id, $chars[$i], $sentences );
        }
    }
    close FI;
}

# return a list of sentences from an .xml file
sub get_sentences {
    my ( $xmlfile ) = @_;
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_file($xmlfile)
        or die "Error reading $xmlfile\n";

    my $docu_node = $doc->getElementsByTagName('document')->[0];
    my $sentences_node = $docu_node->getElementsByTagName('sentences')->[0];
    my @sentence_nodes = $sentences_node->getElementsByTagName('sentence');

    my $sentences = [];
    for my $sent_node ( @sentence_nodes ) {
        my $sent = XML2Simple::get_a_sentence($sent_node);
        push @$sentences, $sent;
    }
    
    return $sentences;
}

sub print_sentences {
    my ( $id, $type, $sentences ) = @_;

    for my $i (0..$#$sentences) {
        my $sent = $sentences->[$i];
        my $row = join("\t", $id, $type, $i+1, $sent);
        print "$row\n";
    }
}

sub run_stanford_corenlp {
    my ($args) = @_;

    my $output_directory = $args->{outputDirectory};
    my $opt_filelist = 0;
    my $opt_file = 0;
    my $filelist;
    my $file;
    if (exists $args->{filelist}) {
        $opt_filelist = 1;
        $filelist = $args->{filelist};
    }
    elsif (exists $args->{file}) {
        $opt_file = 1;
        $file = $args->{file};
    }
    else {
        confess "file or filelist argument must be provided\n";
    }

    # 2016/01/26 by minhpqn: use stanford-corenlp version 3.6.0
    my $CLASSPATH = './tools/stanford-corenlp-full-2015-12-09';
    
    my $props = './code/corenlp.properties';
    my $comd = "java -classpath $CLASSPATH/stanford-corenlp-3.6.0.jar:$CLASSPATH/stanford-corenlp-3.6.0-models.jar:$CLASSPATH/xom.jar:$CLASSPATH/joda-time.jar:$CLASSPATH/jollyday.jar:$CLASSPATH/ejml-0.23.jar:$CLASSPATH/slf4j-api.jar:$CLASSPATH/slf4j-simple.jar:$CLASSPATH/stanford-openie.jar:$CLASSPATH/stanford-openie-models.jar -Xmx3g edu.stanford.nlp.pipeline.StanfordCoreNLP -outputDirectory $output_directory -outputExtension .xml -props $props -filelist $filelist";
    system($comd);
}

# Get the list of text files for questions & multiple answers
sub get_list_file {
    my ($datafile, $workdir, $file_list, $validation) = @_;

    my @chars = qw(A B C D);
    my @list;
    open FIN, '<', $datafile or die "Error reading $datafile";
    while (my $line = <FIN>) {
        chomp($line);
        next if $line =~ /^id/;
        
        my ($id, $q, $gold, @answers);
        if ($validation) {
            ($id, $q, @answers) = split("\t", $line);
        }
        else {
            ($id, $q, $gold, @answers) = split("\t", $line);
        }
        write_to($q, "$workdir/$id.txt");
        push @list, "$workdir/$id.txt";

        for my $i (0..$#chars) {
            my $tmpname = "$workdir/$id\_$chars[$i].txt";
            write_to($answers[$i], $tmpname);
            push @list, $tmpname;
        }
    }
    close FIN;

    open FOUT, '>', $file_list or die "Error writing $file_list";
    print FOUT join("\n", @list);
    close FOUT;
}

sub write_to {
    my ($a_string, $file) = @_;
    open FOUT, '>:encoding(UTF-8)', $file or die "$file\n";
    print FOUT "$a_string";
    close FOUT;
}






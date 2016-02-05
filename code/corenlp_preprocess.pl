package CorenlpProcess;
use File::Path qw/mkpath/;
use File::Basename;
use Carp qw/confess/;
use Getopt::Long;
use strict;
use warnings;

# corenlp_preprocess.pl
# preprocess data with stanford_corenlp
# Stanford CoreNLP version: 3.5.2
# Reference: http://nlp.stanford.edu/software/corenlp.shtml

# 
# History
# ----------------------------
# 2016/01/26    add openie in preprocessing
# 2015/10/14    start implementation
#

__PACKAGE__->main() unless caller;

sub _usage {
    print "usage: [Options] datafile tmpdir\n";
    print " [Options]\n";
    print "   --validation\n";
    exit;
}

sub main {
    my $validation;
    GetOptions(
        "validation" => \$validation,
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
    
    my $output = "$datafile.xml";
    my $file_list = "$workdir/list.txt";
    get_list_file($datafile, $workdir, $file_list, $validation);
    run_stanford_corenlp( {filelist => $file_list,
                           outputDirectory => $workdir} );
    combine_parsed_results($datafile, $output, $workdir, $validation);
}

# Combine results parsed by stanford-corenlp into one file
sub combine_parsed_results {
    my ($datafile, $output, $workdir, $validation) = @_;

    my @chars = qw(A B C D);

    open FOUT, '>:encoding(UTF-8)', $output
        or die "Error writing $output";

    print FOUT '<?xml version="1.0" encoding="UTF-8"?>';
    print FOUT "\n";
    print FOUT "<examples>\n";
    
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

        $gold = 'X'if (!defined $gold);

        print FOUT " <example id=\"$id\" answer=\"$gold\">\n";
        print FOUT "  <question>\n";
        print FOUT "   <text>$q</text>\n";
        my $qxml = get_parsed_content("$workdir/$id.txt.xml");
        print FOUT "$qxml\n";
        print FOUT "  </question>\n";

        for my $i (0..$#chars) {
            print FOUT "  <answer id=\"$chars[$i]\">\n";
            print FOUT "   <text>$answers[$i]</text>\n";
            my $axml = get_parsed_content("$workdir/$id\_$chars[$i].txt.xml");
            print FOUT "$axml\n";
            print FOUT "  </answer>\n";
        }
        print FOUT " </example>\n";
    }
    
    close FI;

    print FOUT "</examples>\n";
    close FOUT;
}

# Get parsed content between two tags <sentences> and </sentences>
sub get_parsed_content {
    my ($filename) = @_;
    
    open FIN, '<:encoding(UTF-8)', $filename
        or die "Error reading $filename";

    my @lines;
    my $flag = 0;
    while (my $line = <FIN>) {
        chomp($line);
        if ($line =~ /<sentences>/) {
            push @lines, $line;
            $flag = 1;
            next;
        }
        elsif ($line =~ /<\/sentences>/) {
            push @lines, $line;
            $flag = 0;
            next;
        }

        if ($flag) {
            push @lines, $line;
        }
    }

    close FIN;

    return join("\n", @lines);
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

sub write_to {
    my ($a_string, $file) = @_;
    open FOUT, '>:encoding(UTF-8)', $file or die "$file\n";
    print FOUT "$a_string";
    close FOUT;
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

# Write sentences of data file into the output
sub get_text_data {
    my ($datafile, $textfile) = @_;

    open FIN, '<', $datafile or die "Error reading $datafile";
    open FOUT, '>', $textfile or die "Error writing $textfile";

    while (my $line = <FIN>) {
        chomp($line);
        next if $line =~ /^id/;

        my ($id, $q, $gold, @answers) = split("\t", $line);
        print FOUT join("\n", $q, @answers);
        print FOUT "\n";
    }

    close FOUT;
    close FIN;
}








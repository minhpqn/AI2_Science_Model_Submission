#!/usr/local/bin/perl

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use File::Path qw/mkpath/;
use strict;
use warnings;

# (Change configuration variables as needed.)
my $path_to_index = './ck12_index';
my $ck12_source = './ck12_source';

if ( @ARGV != 2 ) {
    print "usage: txt_source path_to_index\n";
    exit;
}

$ck12_source = shift @ARGV;
$path_to_index = shift @ARGV;

if ( !-d $path_to_index ) {
    mkpath( $path_to_index );
}

system("rm -rf $path_to_index/*");

use File::Spec::Functions qw( catfile );
use Lucy::Plan::Schema;
use Lucy::Plan::FullTextType;
use Lucy::Analysis::EasyAnalyzer;
use Lucy::Index::Indexer;

# Create Schema.
my $schema = Lucy::Plan::Schema->new;
my $easyanalyzer = Lucy::Analysis::EasyAnalyzer->new(
    language => 'en',
);
my $content_type = Lucy::Plan::FullTextType->new(
    analyzer      => $easyanalyzer,
);
my $url_type = Lucy::Plan::StringType->new( indexed => 0, );
my $cat_type = Lucy::Plan::StringType->new( stored => 0, );
$schema->spec_field( name => 'content',  type => $content_type );
$schema->spec_field( name => 'url',      type => $url_type );

# Create an Indexer object.
my $indexer = Lucy::Index::Indexer->new(
    index    => $path_to_index,
    schema   => $schema,
    create   => 1,
    truncate => 1,
);

# Collect names of source files.
opendir( my $dh, $ck12_source )
    or die "Couldn't opendir '$ck12_source': $!";
my @filenames = grep { $_ =~ /\.txt/ } readdir $dh;

print "Source docs: $ck12_source\n";
print "Index directory: $path_to_index\n";
# Iterate over list of source files.
for my $filename (@filenames) {
    # print "Indexing $filename\n";
    my $doc = parse_file($filename);
    $indexer->add_doc($doc);
}

# Finalize the index and print a confirmation message.
$indexer->commit;
print "Finished!\n";
print "Number of files: ", $#filenames + 1, "\n";

# the fields body,url
sub parse_file {
    my $filename = shift;
    my $filepath = catfile( $ck12_source, $filename );
    open( my $fh, '<:encoding(UTF-8)', $filepath )
        or die "Can't open '$filepath': $!";
    my $text = do { local $/; <$fh> };    # slurp file content
    return {
        content  => $text,
        url      => "$ck12_source/$filename",
    };
}


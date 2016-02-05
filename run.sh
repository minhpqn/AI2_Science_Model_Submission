#!/bin/sh

# Perform prediction from input data

# usage: ./run.sh --with_label input_file

if [ $# -lt 1 ]
then
    echo "usage: ./run.sh [ --with_label ] input_file"
    exit 1
fi

with_label=0
inputFile=''
if [ "$1" == "--with_label" ]
then
    with_label=1
    if [ $# -lt 2 ]
    then        
        echo "input file is missing"
        echo "usage: ./run.sh [ --with_label ] input_file"
        exit 1
    else
        inputFile=$2
    fi
    
elif [ $# -eq 2 -a "$1" != "--with_label" ]
then    
    echo "usage: ./run.sh [ --with_label ] input_file"
    exit 1
else
    inputFile=$1
fi

echo "Input file: $inputFile"
echo "Preprocess inputFile using Stanford CoreNLP version 3.6.0..."
if [ $with_label -eq 1 ]
then
    perl code/corenlp_preprocess.pl $inputFile ./tmp
else
    perl code/corenlp_preprocess.pl --validation $inputFile ./tmp
fi

echo "Convert .xml file to .elem file..."
perl code/xml2simple.pl $inputFile.xml > $inputFile.elem
echo "---------------------------------"

echo "Building queries for search engine"
perl code/build_lucene_query.pl $inputFile.elem
echo "---------------------------------"

echo "Get predictions"
basename=`basename $inputFile`
labelOptions=""
if [ $with_label -eq 1 ]
then
    labelOptions="--gold_data $inputFile"
fi

perl ./code/get_final_answer_by_pair_score.pl --page_size 5 --index data/ck12_index --output $basename.submission $labelOptions $basename.query.txt



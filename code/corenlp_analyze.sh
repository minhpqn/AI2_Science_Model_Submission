#!/bin/sh

# Date: 2016/01/30
# Analyze a text file containing of sentences (one sentence per line)
# Output the parsing results of sentences (one sentence per line)
# -------------------------------------
# CoreNLP version 3.6
# http://stanfordnlp.github.io/CoreNLP/
#

if [ $# -lt 1 ]
then    
    echo "input text file is missing"
    echo "usage: $0 <input>"
    exit
fi

input=$1
CLASSPATH=/Users/minhpham/nlp/local-tools/stanford-corenlp-full-2015-12-09
props=./code/corenlp.properties

outputDirectory=`dirname $input`

echo "Input file: $input"
echo "Output directory: $outputDirectory"

java -classpath $CLASSPATH/stanford-corenlp-3.6.0.jar:$CLASSPATH/stanford-corenlp-3.6.0-models.jar:$CLASSPATH/xom.jar:$CLASSPATH/joda-time.jar:$CLASSPATH/jollyday.jar:$CLASSPATH/ejml-0.23.jar:$CLASSPATH/slf4j-api.jar:$CLASSPATH/slf4j-simple.jar:$CLASSPATH/stanford-openie.jar:$CLASSPATH/stanford-openie-models.jar -Xmx3g edu.stanford.nlp.pipeline.StanfordCoreNLP -ssplit.eolonly -outputDirectory $outputDirectory -outputExtension .xml -props $props -file $input

# convert xml to elem
# perl ./code/xml2elem.pl $input.xml > $input.elem

echo "XML output: $input.xml"
# echo "One-sentence-per-line output: $input.elem";





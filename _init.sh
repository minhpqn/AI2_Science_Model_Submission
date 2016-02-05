#!/bin/sh

# download tools, indexing data

echo "Indexing text collection"
sh ./indexing.sh
echo "--------------------------"

cd ./tools
rm -rf stanford-corenlp-full-2015-12-09
echo "Download Stanford CoreNLP version 3.6.0..."
sh download.sh

cd ../



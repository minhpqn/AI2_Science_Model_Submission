# The Allen AI Science Challenge
Pham Quang Nhat Minh

Competition homepage: [https://www.kaggle.com/c/the-allen-ai-science-challenge](https://www.kaggle.com/c/the-allen-ai-science-challenge).

## Hardware requirement
We run the model on Mac OS enviroment. Memory: 16GB, 2.6 GHz Core i7.

## Software requirement
The program use the following softwares for text analysis and information retrieval.

- [Stanford CoreNLP version 3.6.0](http://stanfordnlp.github.io/CoreNLP/)
- [Apache Lucy](http://lucy.apache.org/) for information retrieval

## How to run the model on the test set

### Indexing the text collection
Run the script indexing.sh in the root directory of the project

sh ./indexing.sh

### Download Stanford CoreNLP version 3.6.0 for text analysis
Go to the directory ./tools and run the shell script download.sh

cd ./tools

sh download.sh

### Run the model on the test data set
Given the test data with the same format as validation data set (without information about correct answers), under the root directory of the project, run the shell script run.sh with the filename of the test data as its argument.

sh run.sh <test_data_file>







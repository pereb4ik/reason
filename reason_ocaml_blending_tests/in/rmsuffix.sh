#!/bin/sh

#remove file extension from files

if [[ $# == 0 ]]
then
        echo "Usage: rmsuffix.sh file1 file2 ...\nremove file extension and print filename in quotes"
fi

for name in "$@"
do
        filename=${name%.*}
	echo test \'$filename\'
done

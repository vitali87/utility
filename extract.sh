#!/bin/bash

function extract() {
if [[ $1 == *.tar.xz ]] || [[ $1 == *.tar.gz ]] || [[ $1 == *.tar.bz2 ]] || [[ $1 == *.tar ]] || [[ $1 == *.tgz ]]; then 
	tar -xvf $1
elif [[ $1 == *.bz ]] || [[ $1 == *.bz2 ]] || [[ $1 == *.tbz ]] || [[ $1 == *.tbz2 ]]; then
	bzip2 -d -k $1
elif [[ $1 == *.gz ]]; then
	gunzip $1
elif [[ $1 == *.zip ]]; then
       	unzip $1
elif [[ $1 == *.jar ]]; then
       	jar -xvf $1
elif [[ $1 == *.Z ]]; then
	zcat $1 | tar -xvf -
elif [[ $1 == *.rar ]]; then
	unrar e $1
fi
}


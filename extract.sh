#!/bin/bash

function extract() {
if [[ $1 == *.tar.xz ]] || [[ $1 == *.tar.gz ]] || [[ $1 == *.tar.bz2 ]]
then
 tar -xvf $1
else 
 if [[ "$1" == *.zip ]] 
 then
  unzip $1
 fi
fi
}


#!/bin/bash

formats=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar)
function extract() {
  if [[ "$1" == *"${formats[0]}" ]] ||
    [[ "$1" == *"${formats[1]}" ]] ||
    [[ "$1" == *"${formats[2]}" ]] ||
    [[ "$1" == *"${formats[3]}" ]] ||
    [[ "$1" == *"${formats[4]}" ]]; then
    tar -xvf "$1"
  elif [[ "$1" == *"${formats[5]}" ]] ||
    [[ "$1" == *"${formats[6]}" ]] ||
    [[ "$1" == *"${formats[7]}" ]] ||
    [[ "$1" == *"${formats[8]}" ]]; then
    bzip2 -d -k "$1"
  elif [[ "$1" == *"${formats[9]}" ]]; then
    gunzip "$1"
  elif [[ "$1" == *"${formats[10]}" ]]; then
    unzip "$1"
  elif [[ "$1" == *"${formats[11]}" ]]; then
    jar -xvf "$1"
  elif [[ "$1" == *"${formats[12]}" ]]; then
    zcat "$1" | tar -xvf -
  elif [[ "$1" == *"${formats[13]}" ]]; then
    unrar e "$1"
  else
    echo "Please specify a correct archive format: "${formats[@]}""
  fi
}

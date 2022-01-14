#!/bin/bash

formats=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar)
extract () {
  if
    [[ "$1" == *"${formats[0]}" ]] ||
    [[ "$1" == *"${formats[1]}" ]] ||
    [[ "$1" == *"${formats[2]}" ]] ||
    [[ "$1" == *"${formats[3]}" ]] ||
    [[ "$1" == *"${formats[4]}" ]]; then
    tar -xvf "$1" -C "$2"
  elif
    [[ "$1" == *"${formats[5]}" ]] ||
    [[ "$1" == *"${formats[6]}" ]] ||
    [[ "$1" == *"${formats[7]}" ]] ||
    [[ "$1" == *"${formats[8]}" ]]; then
    bzip2 -d -k "$1"
  elif
    [[ "$1" == *"${formats[9]}" ]]; then
    gunzip "$1" -c > "$2"
  elif
    [[ "$1" == *"${formats[10]}" ]] ||
    [[ "$1" == *"${formats[11]}" ]]; then
    unzip "$1" -d "$2"
  elif
    [[ "$1" == *"${formats[12]}" ]]; then
    zcat "$1" | tar -xvf - -C "$2"
  elif
    [[ "$1" == *"${formats[13]}" ]]; then
    rar x "$1" "$2"
  else
    echo "Please specify a correct archive format: \"${formats[*]}\""
  fi
}

str_seq () {
  str="$1"
  n="$2"
  user_delim="$3"
  delim=${user_delim:-"_"}

  declare -a out

  for i in $(seq "$n"); do
    out+=("$str$delim$i")
    done

  echo "${out[@]}"
}

peek () {
  default=25
  n=$(xsv headers "$1" | wc -l)
  n_1=$((n - 1))
  user_n="$2"
  choice="${user_n:-"$default"}"
  len=$((choice + 1))
  user_n_2=$((choice - 2))

  if [ "$n" -gt "$default" ]; then
      < "$1" xsv select 1-"$user_n_2","$n_1","$n" | head -n "$len" | xsv table;
  else
     < "$1" xsv select 1-"${user_n:-$n}" | head -n "$len" | xsv table;
  fi
}


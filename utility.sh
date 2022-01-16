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

startup_remove () {
	sudo update-rc.d -f $1 remove
}

get () {
	  arg1="$1"
	  arg2="$2"
	if [[ $arg1 == ip_external ]]; then
		curl ifconfig.me
	elif [[ $arg1 == cmd_most_often ]]; then
		history| awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' | sort -rn | head
	elif [[ $arg1 == ps_ram ]]; then
		user_n=$arg2
		ps aux | sort -nk +4 | tail -n "${user_n:-10}"
	fi
}

complete -W "ip_external cmd_most_often ps_ram" get


remove () {
	arg1="$1"
	arg2="$2"

	if [[ $arg1 == duplicates ]]; then
		awk '!x[$0]++' "$2"
	fi
}
complete -W "duplicates" remove

# convert files' spaces into underscores
underscorise () {
	arg1=$1

	if [[ $arg1 == all ]]; then
		rename 'y/ /_/' *
	else 
		rename 'y/ /_/' "$arg1"
	fi
}
complete -W "all <filename>" underscorise

# simple Calculator
? () { 
	echo "$*" | bc -l; 
}

# single line for creating and entering directory
mkdircd () {
	mkdir "$1" && cd $_
}

# convert manula page into pdf
man2pdf () {
	man -t "$1" | ps2pdf - "$2".pdf
}
complete -W "man-page pdf-filename-only" man2pdf

# generate random-length passwords etc.
generate () {
	arg1=$1
	arg2=$2
	if [[ $arg1 == "passwd" ]]; then
		strings /dev/urandom | grep -o '[[:alnum:]]' | head -n $arg2 | tr -d '\n'; echo
	fi
}
complete -W "passwd" generate

# graph various important stuff
graph () {
	arg1=$1
	if [[ $arg1 == "connection" ]]; then
		netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }' 
	fi
}
complete -W "connection" graph

# search what pattern where
search () {
	arg1=$1
	arg2=$2

	grep -RnisI $arg1 $arg2
}
complete -W "all <filename>" search

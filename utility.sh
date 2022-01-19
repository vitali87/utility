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

get () {
	  arg1="$1"
	  arg2="$2"
	  user_n=$arg2
    arg3="$3"

	if [[ $arg1 == ip_external ]]; then
		curl ifconfig.me
	elif [[ $arg1 == cmd_most_often ]]; then
		history| awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' | sort -rn | head -n "${user_n:-10}"
	elif [[ $arg1 == ps_ram ]]; then
		ps aux | sort -nk +4 | tail -n "${user_n:-10}"
	elif [[ $arg1 == memory ]]; then
		watch -n 5 -d '/bin/free -m'
	elif [[ $arg1 == function_loaded ]]; then
		shopt -s extdebug;declare -F | grep -v "declare -f _" | declare -F $(awk "{print $3}") | column -t;shopt -u extdebug
	elif [[ $arg1 == email ]]; then
	  # Before using this function, create an App password in your google account
	  # And use it instead of your password
	  read -r -p 'Username: ' uservar
	  read -r -sp 'Password: ' passvar
	  curl -u "$uservar":"$passvar" --silent "https://mail.google.com/mail/feed/atom" | tr -d '\n' | awk -F '<entry>' '{for (i=2; i<=NF; i++) {print $i}}' | sed -n "s/<title>\(.*\)<\/title.*name>\(.*\)<\/name>.*/\2 - \1/p"
	elif [[ $arg1 == distro ]]; then
	    cat /etc/issue
	elif [[ $arg1 == line ]]; then
	    sed -n "$arg2"p "$arg3"
	elif [[ $arg1 == weather_forecast ]]; then
	    curl wttr.in/"$arg2"
	elif [[ $arg1 == directory ]]; then
	    ls -d /*
	elif [[ $arg1 == program_on_port ]]; then
	    lsof -i tcp:"$arg2"
	elif [[ $arg1 == usage_by_directory ]]; then
	    du -b --max-depth "${arg2:-1}" | sort -nr | perl -pe 's{([0-9]+)}{sprintf "%.1f%s", $1>=2**30? ($1/2**30, "G"): $1>=2**20? ($1/2**20, "M"): $1>=2**10? ($1/2**10, "K"): ($1, "")}e'
	elif [[ $arg1 == files_modified ]]; then
	    sudo find / -mmin "$2" -type f
	elif [[ $arg1 == apps_using_internet ]]; then
	    lsof -P -i -n | cut -f 1 -d " "| uniq | tail -n +2
 	elif [[ $arg1 == file_or_directory && "$arg2" == big ]]; then
	    sudo du -sm *|sort -n|tail
	fi
}
complete -W "ip_external cmd_most_often ps_ram memory function_loaded email line weather_forecast directory program_on_port usage_by_directory files_modified apps_using_internet file_or_directory" get


remove () {
	arg1="$1"
	arg2="$2"
	arg3="$3"
	arg4="$4"

	if [[ $arg1 == duplicates ]]; then
		awk '!x[$0]++' "$2"
	elif [[ $arg1 == dir && $arg2 == empty ]]; then
	  find . -type d -empty -delete
	elif [[ $arg1 == program_at_system_startup ]]; then
	  sudo update-rc.d -f "$2" remove
	elif [[ $arg1 == line && $arg2 == blank ]]; then
	  grep . "$arg3" > "$arg4"
	elif [[ $arg1 == line ]]; then
	  sed -i "$arg2"d "$arg3"
	fi
}

complete -W "duplicates dir program_at_system_startup line" remove

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

# simple calculator
calculate () {
	echo "$*" | bc -l; 
}

# single line for creating and entering directory
mkdircd () {
	mkdir "$1" && cd "$_" || exit
}

# convert manual page into pdf
man2pdf () {
	man -t "$1" | ps2pdf - "$2".pdf
}
complete -W "man-page pdf-filename-only" man2pdf

# generate random-length passwords etc.
generate () {
	arg1=$1
	arg2=$2
	if [[ $arg1 == "passwd" ]]; then
		strings /dev/urandom | grep -o '[[:alnum:]]' | head -n "$arg2" | tr -d '\n'; echo
	elif [[ $arg1 == "str_seq" ]]; then
	  str="$2"
	  n="$3"
	  user_delim="$4"
	  delim=${user_delim:-"_"}

    declare -a out

    for i in $(seq "$n"); do
      out+=("$str$delim$i")
      done

    echo "${out[@]}"
  elif [[ $arg1 == "graph" && $arg2 == "connection" ]]; then # graph various important stuff
		netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }'
	fi

}
complete -W "passwd str_seq graph" generate

# search what pattern where
search () {
	arg1=$1
	arg2=$2

	grep -RnisI "$arg1" "$arg2"
}
complete -W "all <filename>" search

# replace slashes back and forth
replace () {
	if [[ "$2" == to_back ]]; then
		sed -i 's|\/|\\|g' "$1"
	elif [[ "$2" == to_forth ]]; then
		sed -i 's|\\|\/|g' "$1"
	fi
}
complete -W "to_back to_forth" replace

check () {
  if [[ "$1" == syntax ]]; then
    find . -name '*.sh' -exec bash -n {} \;
  elif [[ "$1" == ssl_certificate_dates ]]; then
    echo | openssl s_client -connect "$2":443 2>/dev/null |openssl x509 -dates -noout
  fi
}
complete -W "syntax ssl_certificate_dates" check

leave () {
  if [[ "$2" == only ]]; then
    rm -r !("$1")
  fi

}
complete -W "syntax ssl_certificate_dates" leave

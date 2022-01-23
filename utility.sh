#!/bin/bash

formats=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar)
extract() {
  if
    [[ "$1" == *"${formats[0]}" ]] \
      || [[ "$1" == *"${formats[1]}" ]] \
      || [[ "$1" == *"${formats[2]}" ]] \
      || [[ "$1" == *"${formats[3]}" ]] \
      || [[ "$1" == *"${formats[4]}" ]]
  then
    tar -xvf "$1" -C "$2"
  elif
    [[ "$1" == *"${formats[5]}" ]] \
      || [[ "$1" == *"${formats[6]}" ]] \
      || [[ "$1" == *"${formats[7]}" ]] \
      || [[ "$1" == *"${formats[8]}" ]]
  then
    bzip2 -d -k "$1"
  elif
    [[ "$1" == *"${formats[9]}" ]]
  then
    gunzip "$1" -c > "$2"
  elif
    [[ "$1" == *"${formats[10]}" ]] \
      || [[ "$1" == *"${formats[11]}" ]]
  then
    unzip "$1" -d "$2"
  elif
    [[ "$1" == *"${formats[12]}" ]]
  then
    zcat "$1" | tar -xvf - -C "$2"
  elif
    [[ "$1" == *"${formats[13]}" ]]
  then
    rar x "$1" "$2"
  else
    echo "Please specify a correct archive format: \"${formats[*]}\""
  fi
}

peek() {
  default=25
  n=$(xsv headers "$1" | wc -l)
  n_1=$((n - 1))
  user_n="$2"
  choice="${user_n:-"$default"}"
  len=$((choice + 1))
  user_n_2=$((choice - 2))

  if [ "$n" -gt "$default" ]; then
    xsv < "$1" select 1-"$user_n_2","$n_1","$n" | head -n "$len" | xsv table
  else
    xsv < "$1" select 1-"${user_n:-$n}" | head -n "$len" | xsv table
  fi
}

get() {
  arg1="$1"
  arg2="$2"
  user_n=$arg2
  arg3="$3"

  if [[ $arg1 == ip && $arg2 == external ]]; then
    curl ifconfig.me
  elif [[ $arg1 == ip && $arg2 == connected ]]; then
    netstat -lantp | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort -u
  elif [[ $arg1 == commands_most_often ]]; then
    history | awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' \
      | sort -rn | head -n "${user_n:-10}"
  elif [[ $arg1 == process_ram ]]; then
    ps aux | sort -nk +4 | tail -n "${user_n:-10}"
  elif [[ $arg1 == memory ]]; then
    watch -n 5 -d '/bin/free -m'
  elif [[ $arg1 == functions_loaded ]]; then
    shopt -s extdebug
    declare -F | grep -v "declare -f _" | declare -F $(awk "{print $3}") | column -t
    shopt -u extdebug
  elif [[ $arg1 == email ]]; then
    # Before using this function, create an App password in your google account
    # And use it instead of your password
    read -r -p 'Username: ' uservar
    read -r -sp 'Password: ' passvar
    curl -u "$uservar":"$passvar" --silent "https://mail.google.com/mail/feed/atom" \
      | tr -d '\n' | awk -F '<entry>' '{for (i=2; i<=NF; i++) {print $i}}' \
      | sed -n "s/<title>\(.*\)<\/title.*name>\(.*\)<\/name>.*/\2 - \1/p"
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
    du -b --max-depth "${arg2:-1}" | sort -nr \
      | perl -pe 's{([0-9]+)}{sprintf "%.1f%s",
       $1>=2**30? ($1/2**30, "G"): $1>=2**20? ($1/2**20, "M"):
        $1>=2**10? ($1/2**10, "K"): ($1, "")}e'
  elif [[ $arg1 == files_modified ]]; then
    sudo find / -mmin "$2" -type f
  elif [[ $arg1 == apps_using_internet ]]; then
    lsof -P -i -n | cut -f 1 -d " " | uniq | tail -n +2
  elif [[ $arg1 == files_or_directories && "$arg2" == big ]]; then
    sudo du -sm * | sort -n | tail
  elif [[ $arg1 == number_of_lines ]]; then
    wc < "$arg2" -l
  elif [[ $arg1 == files_opened ]]; then
    lsof -c "$arg2"
  elif [[ $arg1 == network_connections ]]; then
    netstat -ant | awk '{print $NF}' | grep -v '[a-z]' | sort | uniq -c
  elif [[ $arg1 == permissions && "$arg2" == octal ]]; then
    stat -c '%A %a %n' *
  elif [[ $arg1 == geo_location_from_ip ]]; then
    curl -s get http://ip-api.com/json/"$arg2" \
      | jq 'with_entries(select([.key] | inside(["country", "city", "lat", "lon"])))'
  elif [[ $arg1 == packages && $arg2 == installed ]]; then
    dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n
  fi
}
_get_completions() {
  # Cannot use ls as it can be aliased to ls -lrta
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  ip_external="ip\ external"
  ip_connected="ip\ connected"
  packages_installed="packages\ installed"
  files_or_directories_big="files_or_directories\ big"
  permissions_octal="permissions\ octal"

  mapfile -t COMPREPLY < <(compgen -W "$ip_external external $ip_connected
  connected commands_most_often process_ram memory functions_loaded email
  line weather_forecast directory program_on_port usage_by_directory
  files_modified apps_using_internet $files_or_directories_big number_of_lines
  files_opened network_connections $permissions_octal geo_location_from_ip
  $packages_installed $cur_dir" -- $cur)
}
complete -F _get_completions get

remove() {
  arg1="$1"
  arg2="$2"
  arg3="$3"
  arg4="$4"

  if [[ $arg1 == duplicates ]]; then
    awk '!x[$0]++' "$arg2"
  elif [[ $arg1 == dirs && $arg2 == empty ]]; then
    find . -type d -empty -delete
  elif [[ $arg1 == program_at_system_startup ]]; then
    sudo update-rc.d -f $arg2 remove
  elif [[ $arg1 == lines && $arg2 == blank ]]; then
    grep . "$arg3" > "$arg4"
  elif [[ $arg1 == lines ]]; then
    sed -i "$arg2"d "$arg3"
  fi
}
_remove_completions() {
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  dirs_empty="dirs\ empty"
  lines_blank="lines\ blank\ <old-filename>\ <new-filename>"
  duplicates="duplicates\ <file>"
  program_at_system_startup="program_at_system_startup\ <program>"
  lines="lines\ <line-number>\ <filename>"

  mapfile -t COMPREPLY < <(compgen -W "$duplicates $dirs_empty empty $program_at_system_startup $lines_blank blank $lines $cur_dir" -- $cur)
}
complete -F _remove_completions remove

# simple calculator
calculate() {
  echo "$*" | bc -l
}

# single line for creating and entering directory
mkdircd() {
  mkdir "$1" && cd "$_" || exit
}

# convert x to y
recast() {
  if [[ $1 == man2pdf ]]; then
    man -t "$2" | ps2pdf - "$3".pdf
  elif [[ $1 == txt2table ]]; then
    column -tns: "$2"
  elif [[ $1 == space2_ && $# -eq 1 ]]; then # convert all files' spaces into underscores
    rename 'y/ /_/' -- *
  elif [[ $1 == space2_ && $# -eq 2 ]]; then # convert one file's spaces into underscores
    rename 'y/ /_/' "$2"
  fi
}
_recast_completions() {
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  man2pdf="man2pdf\ <man_name>\ <pdf_name>"
  txt2table="txt2table\ <txt-file>"
  space2_="space2_\ [<file>]"

  mapfile -t COMPREPLY < <(compgen -W "$man2pdf $txt2table $space2_ $cur_dir" -- $cur)
}
complete -F _recast_completions recast

# generate random-length passwords etc.
generate() {
  arg1=$1
  arg2=$2
  if [[ $arg1 == passwd ]]; then
    strings /dev/urandom | grep -o '[[:alnum:]]' \
      | head -n "$arg2" | tr -d '\n'
    echo
  elif [[ $arg1 == str_num_seq ]]; then
    str="$2"
    n="$3"
    user_delim="$4"
    delim=${user_delim:-"_"}

    declare -a out

    for i in $(seq "$n"); do
      out+=("$str$delim$i")
    done

    echo "${out[@]}"
  elif [[ $arg1 == graph && $arg2 == connection ]]; then # graph various important stuff
    netstat -an | grep ESTABLISHED | awk '{print $5}' \
      | awk -F: '{print $1}' | sort | uniq -c \
      | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }'
  fi

}
_generate_completions() {
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  graph="graph\ connection"
  str_num_seq="str_num_seq\ <str>\ <number>"
  passwd="passwd\ <length>"

  mapfile -t COMPREPLY < <(compgen -W "$passwd $str_num_seq $graph" -- $cur)
}
complete -F _generate_completions generate

# search what pattern where
search() {
  arg1=$1
  arg2=$2

  grep -RnisI "$arg1" "$arg2"
}
_search_completions() {
  # Cannot use ls as it can be aliased to ls -lrta
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  mapfile -t COMPREPLY < <(compgen -W "$cur_dir" -- $cur)
}
complete -F _search_completions search

replace() {
  # replace slashes back
  if [[ "$1" == slashes_in_filenames && "$2" == to_back ]]; then
    sed -i 's|\/|\\|g' "$3"
  # replace slashes forth
  elif [[ "$1" == slashes_in_filenames && "$2" == to_forth ]]; then
    sed -i 's|\\|\/|g' "$3"
  elif [[ "$1" == string_in_files ]]; then
    grep -rl "$2" "$4" | xargs sed -i -e "s/$2/$3/"
  fi
}
_replace_completions() {
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  slashes_back="slashes_in_filenames\ to_back"
  slashes_forth="slashes_in_filenames\ to_forth"
  string_in_files="string_in_files\ <old-string>\ <new-string>\ <files>"

  mapfile -t COMPREPLY < <(compgen -W "$slashes_back $slashes_forth $string_in_files $cur_dir" -- $cur)
}
complete -F _replace_completions replace

check() {
  if [[ "$1" == syntax ]]; then
    find . -name '*.sh' -exec bash -n {} \;
  elif [[ "$1" == ssl_certificate_dates ]]; then
    echo | openssl s_client -connect "$2":443 2> /dev/null \
      | openssl x509 -dates -noout
  fi
}
ssl_certificate_dates="ssl_certificate_dates\ <website-name>"
complete -W "syntax ssl_certificate_dates" check

leave() {
  if [[ "$2" == only ]]; then
    rm -r !("$1")
  fi
}
complete -W "only $cur_dir" leave

compress() {
  if [[ "$1" == working_directory ]]; then
    tar -cf - . | pv -s "$(du -sb . | awk '{print $1}')" \
      | tar -xvf $1 > out.tar.gz
  fi
}
complete -W "working_directory" compress

schedule() {
  if [[ "$1" == script_or_command ]]; then
    ( (
      sleep "$3""$4"
      "$2"
    ) &)
  fi
}
_schedule_completions() {
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  mapfile -t COMPREPLY < <(compgen -W "script_or_command $cur_dir" -- $cur)
}
complete -F _schedule_completions schedule

drop() {
  if [[ $1 == column ]]; then
    cut -d , -f "$2" "$3" --complement > file-new.csv
    mv file-new.csv "$3"
  elif [[ $1 == row ]]; then
    sed -i "$2d" file.csv
  fi
}
_drop_completions() {
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  mapfile -t COMPREPLY < <(compgen -W "column row $cur_dir" -- $cur)
}
complete -F _drop_completions drop

limit() {
  if [[ $1 == cpu_for_process ]]; then
    nice -n "$2" "$3"
  fi
}
cpu_for_process="cpu_for_process\ <percent>\ <process>"
complete -W "$cpu_for_process" limit

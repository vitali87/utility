#!/bin/bash

formats=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar .7z .tar.lzma .xz .lzma)
extract() {
  second=${2:-"."}
  if
    [[ "$1" == *"${formats[0]}" ]] \
      || [[ "$1" == *"${formats[1]}" ]] \
      || [[ "$1" == *"${formats[2]}" ]] \
      || [[ "$1" == *"${formats[3]}" ]] \
      || [[ "$1" == *"${formats[4]}" ]]
  then
    tar -xvf "$1" -C "$second"
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
    gunzip "$1" -c > "$second"
  elif
    [[ "$1" == *"${formats[10]}" ]] \
      || [[ "$1" == *"${formats[11]}" ]]
  then
    unzip "$1" -d "$second"
  elif
    [[ "$1" == *"${formats[12]}" ]]
  then
    zcat "$1" | tar -xvf - -C "$second"
  elif
    [[ "$1" == *"${formats[13]}" ]]
  then
    rar x "$1" "$second"
  elif
    [[ "$1" == *"${formats[14]}" ]]
  then
    7z x "$1" "-o$second"
  elif
    [[ "$1" == *"${formats[15]}" ]]
  then
        tar -xf "$1" -C "$second" --lzma
  elif
    [[ "$1" == *"${formats[16]}" ]]
  then
    unxz "$1" -C "$second"
  elif
    [[ "$1" == *"${formats[17]}" ]]
  then
    unlzma "$1" -C "$second"
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

  # external ip address
  if [[ $arg1 == ip && $arg2 == external ]]; then
    curl ifconfig.me
  # internal ip address
  elif [[ $arg1 == ip && $arg2 == internal ]]; then
    hostname -I | awk '{print $1}'
  # connected ip addresses
  elif [[ $arg1 == ip && $arg2 == connected ]]; then
    netstat -lantp | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort -u
  # commands that are used most often
  elif [[ $arg1 == commands_most_often ]]; then
    history | awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' \
      | sort -rn | head -n "${user_n:-10}"
  # RAM consumed by a process
  elif [[ $arg1 == process_ram ]]; then
    ps aux | sort -nk +4 | tail -n "${user_n:-10}"
  # memory used, free, available
  elif [[ $arg1 == memory ]]; then
    watch -n 5 -d '/bin/free -m'
  # which functions are loaded?
  elif [[ $arg1 == functions_loaded ]]; then
    shopt -s extdebug
    declare -F | grep -v "declare -f _" | declare -F $(awk "{print $3}") | column -t
    shopt -u extdebug
  # Fetch gmail inbox titles
  elif [[ $arg1 == email ]]; then
    # Before using this function, create an App password in your google account
    # And use it instead of your password
    read -r -p 'Username: ' uservar
    read -r -sp 'Password: ' passvar
    curl -u "$uservar":"$passvar" --silent "https://mail.google.com/mail/feed/atom" \
      | tr -d '\n' | awk -F '<entry>' '{for (i=2; i<=NF; i++) {print $i}}' \
      | sed -n "s/<title>\(.*\)<\/title.*name>\(.*\)<\/name>.*/\2 - \1/p"
  # Which distribution of Linux?
  elif [[ $arg1 == distro ]]; then
    cat /etc/issue
  # print line x in file y
  elif [[ $arg1 == line ]]; then
    sed -n "$arg2"p "$arg3"
  # Fetch weather forecast
  elif [[ $arg1 == weather_forecast ]]; then
    curl wttr.in/"$arg2"
  # Get only directories
  elif [[ $arg1 == directory ]]; then
    ls -d /*
  # Which programs are on port x?
  elif [[ $arg1 == program_on_port ]]; then
    lsof -i tcp:"$arg2"
  # Show usage by directory
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
  elif [[ $arg1 == users && $arg2 == name ]]; then
    awk -F: '{ print $1}' /etc/passwd
  elif [[ $arg1 == users ]]; then
    less /etc/passwd
  elif [[ $arg1 == column_frequency ]]; then
    xsv frequency -s "$2" "$3" | xsv table
  elif [[ $arg1 == speed && ($arg2 == download || $arg2 == upload || -z $arg2) ]]; then
    which speedtest-cli || pip install speedtest-cli && speedtest-cli
  elif [[ $arg1 == info && $arg2 == cpu ]]; then
    lscpu
  elif [[ $arg1 == info && $arg2 == memory ]]; then
    free -h
  elif [[ $arg1 == info && $arg2 == disk ]]; then
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  elif [[ $arg1 == network ]]; then
    ifconfig -a
  elif [[ $arg1 == value && $arg2 == colour ]]; then
    for i in {0..255}; do echo -e "\e[38;05;${i}m${i}"; done | column -c 80 -s '  '; echo -e "\e[m"
  elif [[ $arg1 == repos ]]; then
    curl -s https://api.github.com/users/"$arg2"/repos?per_page=1000 |grep git_url |awk '{print $2}'| sed 's/"(.*)",/^A/'
  elif [[ $arg1 == info && $arg2 == bios ]]; then
    sudo dmidecode -t bios
  elif [[ $arg1 == info && $arg2 == distribution ]]; then
    cat /etc/*release
  elif [[ $arg1 == users && $arg2 == recent ]]; then
    last  | grep -v "^$" | awk '{ print $1 }' | sort -nr | uniq -c
  elif [[ $arg1 == stats && $arg2 == bandwith ]]; then
    ifstat -nt
  elif [[ $arg1 == definition ]]; then
    curl dict://dict.org/d:"$arg2"
  elif [[ $arg1 == branches && $arg2 == date ]]; then
    for k in `git branch|perl -pe s/^..//`;do echo -e `git show --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k|head -n 1`\\t$k;done|sort -r
  elif [[ $arg1 == info && $arg2 == authors ]]; then
    git log --format='%aN' | sort -u
  elif [[ $arg1 == info && $arg2 == bit ]]; then
    getconf LONG_BIT
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
  users_name="users\ name"
  column_frequency="column_frequency\ <column-name>\ <file>"

  mapfile -t COMPREPLY < <(compgen -W "$ip_external external $ip_connected
  connected commands_most_often process_ram memory functions_loaded email
  line weather_forecast directory program_on_port usage_by_directory
  files_modified apps_using_internet $files_or_directories_big number_of_lines
  files_opened network_connections $permissions_octal geo_location_from_ip
  $packages_installed $users_name users $column_frequency $cur_dir" -- $cur)
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
  elif [[ $1 == space2_ && $# -eq 1 ]]; then
    rename 'y/ /_/' -- *
  elif [[ $1 == space2_ && $# -eq 2 ]]; then
    rename 'y/ /_/' "$2"
  elif [[ $1 == json2yaml ]]; then
    jq -M . "$arg2" > "$arg3"
  elif [[ $1 == jpgpng2pdf || $1 == pngjpg2pdf ]]; then
    convert *.png *.jpg output.pdf
  elif [[ $1 == upper2lower ]]; then
    rename 'y/A-Z/a-z/' *
  elif [[ $1 == camel2_ ]]; then
    sed -r 's/([a-z]+)([A-Z][a-z]+)/\1_\l\2/g' "$2"
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

# create random-length passwords etc.
create() {
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
  # replace lines with their trailing text before delimiter: multiple runs will append
  elif [[ "$1" == new_file && "$3" == reduce_by_delimiter ]]; then
    N=$(get number_of_lines "$2")
    for n in $(seq 1 1 $N)
    do
	    a=$(sed -n "$n"p "$2")
	    b=${a%:*}
	    echo "$b" >> "new-""$2"
    done
  elif [[ "$1" == user ]]; then
    sudo useradd "$2"
  fi
}
_create_completions() {
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  graph="graph\ connection"
  str_num_seq="str_num_seq\ <str>\ <number>"
  passwd="passwd\ <length>"
  new_reduce="new_file\ <old-file>\ reduce_by_delimiter\ <delimiter>"
  user_add="user\ <name>"

  mapfile -t COMPREPLY < <(compgen -W "$passwd $str_num_seq $graph $new_reduce $user_add" -- $cur)
}
complete -F _create_completions create

search() {
  arg1=$1
  arg2=$2
  arg3=$3

  if [[ $arg1 == files ]]; then
    grep -RnisI "$arg2" "$arg3"
  elif [[ $arg1 == google ]]; then
    Q="$arg2"; GOOG_URL="http://www.google.com/search?q="; AGENT="Mozilla/4.0"; stream=$(curl -A "$AGENT" -skLm 10 "${GOOG_URL}\"${Q/\ /+}\"" |  grep -oP '\/url\?q=.+?&amp' |  sed 's/\/url?q=//;s/&amp//');  echo -e "${stream//\%/\x}"
  fi

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
  if [[ "$1" == slashes && "$2" == back ]]; then
    sed -i 's|\/|\\|g' "$3"
  # replace slashes forth
  elif [[ "$1" == slashes && "$2" == forth ]]; then
    sed -i 's|\\|\/|g' "$3"
  # replace string "a" with string "b" in files
  elif [[ "$1" == string ]]; then
    grep -rl "$2" "$4" | xargs sed -i -e "s/$2/$3/"
  elif [[ "$1" == tabs && "$2" == spaces ]]; then
    find ./ -type f -exec  sed -i 's/\t/  /g' {} \;
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
complete -W "syntax $ssl_certificate_dates" check

retain() {
  if [[ "$2" == only ]]; then
    rm -r !("$1")
  fi
}
complete -W "only $cur_dir" retain

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

delete() {
  if [[ $1 == column ]]; then # drop col x from a csv
    cut -d , -f "$2" "$3" --complement > file-new.csv
    mv file-new.csv "$3"
  elif [[ $1 == row ]]; then # drop row x from a csv
    sed -i "$2d" file.csv
  elif [[ $1 == user ]]; then # drop row x from a csv
    sudo deluser "$2" # Only root may remove a user or group from the system
  fi
}
_delete_completions() {
  cur_dir=$(
    FILES=(*)
    for file in "${FILES[@]}"; do basename "$file"; done | sed "s/^/'/;s/$/'/"
  )
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  user_name="user <name>"

  mapfile -t COMPREPLY < <(compgen -W "column row $user_name $cur_dir" -- $cur)
}
complete -F _delete_completions delete

limit() {
  if [[ $1 == cpu_for_process ]]; then # cpu utilisation for process x
    nice -n "$2" "$3"
  fi
}
cpu_for_process="cpu_for_process\ <percent>\ <process>"
complete -W "$cpu_for_process" limit

replicate() {
  # replicate current terminal n times
  for i in $(seq 1 1 "$1"); do $(ps -o comm= -p "$(($(ps -o ppid= -p "$(($(ps -o sid= -p "$$")))")))") & done
}

stamp() {
  # stamp pdf with a text
  echo "$2" | enscript -B -f Courier-Bold16 -o- | ps2pdf - | pdftk "$1" stamp - output output.pdf
}

function modify() {
  # setting utility from the terminal
  if [[ $1 == "brightness" && $2 -ge 0 && $2 -le 100 ]]; then
    echo $(( $2 * 12000 / 100 )) | sudo tee /sys/class/backlight/intel_backlight/brightness
  else
    echo "Invalid brightness level. Please enter a value between 0 and 100."
  fi
}
# Autocompletion for modify function
_modify_completions() {
  local cur_arg=${words[CURRENT]}
  if [[ $cur_arg == "brightness" ]]; then
    _arguments '*: :->level'
  else
    _arguments '1: :->brightness'
  fi
}

compdef _modify_completions modify




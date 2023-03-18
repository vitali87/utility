#!/bin/bash

formats=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar .7z .tar.lzma .xz .lzma)

extract() {
  second=${2:-"."}
  lowercase_filename=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  matched=false

  for format in "${formats[@]}"; do
    if [[ "$lowercase_filename" == *"$format" ]]; then
      matched=true
      break
    fi
  done

  if ! $matched; then
    echo "Please specify a correct archive format: \"${formats[*]}\""
    return 1
  fi

  case "$lowercase_filename" in
    *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz)
      tar -xvf "$1" -C "$second" ;;
    *.bz|*.bz2|*.tbz|*.tbz2)
      bzip2 -d -k "$1" ;;
    *.gz)
      gunzip "$1" -c > "$second" ;;
    *.zip|*.jar)
      unzip "$1" -d "$second" ;;
    *.z)
      zcat "$1" | tar -xvf - -C "$second" ;;
    *.rar)
      rar x "$1" "$second" ;;
    *.7z)
      7z x "$1" "-o$second" ;;
    *.tar.lzma)
      tar -xf "$1" -C "$second" --lzma ;;
    *.xz)
      unxz "$1" -c > "$second" ;;
    *.lzma)
      unlzma "$1" -c > "$second" ;;
    *)
      echo "Unknown error occurred."
      return 1 ;;
  esac

  if [ $? -ne 0 ]; then
    echo "An error occurred while extracting the archive."
    return 1
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
  arg3="$3"

  user_n=$arg2

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
  elif [[ $arg1 == git && $arg2 == repos ]]; then
    curl -s https://api.github.com/users/"$arg3"/repos?per_page=1000 |grep git_url |awk '{print $2}'| sed 's/"(.*)",/^A/'
  elif [[ $arg1 == git && $arg2 == branches && $arg3 == date ]]; then
    for k in `git branch|perl -pe s/^..//`;do echo -e `git show --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k|head -n 1`\\t$k;done|sort -r
  elif [[ $arg1 == git && $arg2 == info ]]; then
    if [[ -z "$arg3" || "$arg3" != "authors" ]]; then
      echo "Error: The third argument must be on these options: authors"
    else
      git log --format='%aN' | sort -u
    fi
  elif [[ $arg1 == info && $arg2 == bit ]]; then
    getconf LONG_BIT
  elif [[ $arg1 == password ]]; then
    if [[ -z "$arg2" ]]; then
      echo "Please provide the SSID"
    else
      sudo cat /etc/NetworkManager/system-connections/"$arg2" | grep psk=
    fi
  elif [[ $arg1 == applications ]]; then
    ls /usr/share/applications/ 
  fi
}
_get_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local options=(
    "ip external"
    "ip internal"
    "ip connected"
    "commands_most_often"
    "process_ram"
    "memory"
    "functions_loaded"
    "email"
    "distro"
    "line"
    "weather_forecast"
    "directory"
    "program_on_port"
    "usage_by_directory"
    "files_modified"
    "apps_using_internet"
    "files_or_directories big"
    "number_of_lines"
    "files_opened"
    "network_connections"
    "permissions octal"
    "geo_location_from_ip"
    "packages installed"
    "users name"
    "users"
    "column_frequency"
    "speed download"
    "speed upload"
    "info cpu"
    "info memory"
    "info disk"
    "network"
    "value colour"
    "info bios"
    "info distribution"
    "users recent"
    "stats bandwith"
    "definition"
    "git repos"
    "git branches date"
    "git info authors"
    "info bit"
    "password"
    "applications"
  )
  if [[ "$prev" == "git" ]]; then
    case "$cur" in
      repos|branches|info)
        options=( "repos" "branches date" "info authors" )
        ;;
    esac
  elif [[ "$prev" == "speed" ]]; then
    options=( "download" "upload" )
  elif [[ "$prev" == "permissions" ]]; then
    options=( "octal" )
  elif [[ "$prev" == "files_or_directories" ]]; then
    options=( "big" )
  elif [[ "$prev" == "info" ]]; then
    options=( "cpu" "memory" "disk" "bios" "distribution" "bit" )
  elif [[ "$prev" == "ip" ]]; then
    options=( "external" "internal" "connected" )
  elif [[ "$prev" == "line" ]]; then
    options=( "all" )
  elif [[ "$prev" == "value" ]]; then
    options=( "colour" )
  fi
  COMPREPLY=( $(compgen -W "${options[*]}" -- "$cur") )
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
  local cur opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  opts="duplicates dirs program_at_system_startup lines"

  case "${COMP_WORDS[1]}" in
    duplicates)
      # No completions needed for the second argument as it's a file path
      return
      ;;
    dirs)
      opts="empty"
      ;;
    program_at_system_startup)
      # No completions needed for the second argument as it's a program name
      return
      ;;
    lines)
      opts="blank"
      ;;
  esac

  COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
}
complete -F _remove_completions remove

calculate() {
  case "$2" in
    +)
      echo "$(($1 + $3))"
      ;;
    -)
      echo "$(($1 - $3))"
      ;;
    "*")
      echo "$(($1 * $3))"
      ;;
    /)
      echo "$(bc -l <<< "$1 / $3")"
      ;;
    ^)
      echo "$(bc -l <<< "$1 ^ $3")"
      ;;
    %)
      echo "$(($1 % $3))"
      ;;
  esac

  case "$1" in
    sin)
      echo "$(bc -l <<< "s($2)")"
      ;;
    cos)
      echo "$(bc -l <<< "c($2)")"
      ;;
    tan)
      echo "$(bc -l <<< "s($2) / c($2)")"
      ;;
    log)
      echo "$(bc -l <<< "l($2) / l(10)")"
      ;;
    ln)
      echo "$(bc -l <<< "l($2)")"
      ;;
    sqrt)
      echo "$(bc -l <<< "sqrt($2)")"
      ;;
    *)
      if [ -z "$2" ]; then
        echo "Invalid operation. Please enter a valid operation and two numbers."
        echo "Usage: calculate [number1] [operation] [number2]"
        echo "Operations: +, -, *, /, ^, %, sin, cos, tan, log, ln, sqrt"
      fi
      ;;
  esac
}
_calculate_options() {
  local cur prev opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [ $COMP_CWORD -eq 1 ]; then
    opts="+ - * / ^ % sin cos tan log ln sqrt"
  elif [ $COMP_CWORD -eq 2 ]; then
    case "$prev" in
      sin | cos | tan | log | ln | sqrt)
        opts=""
        ;;
      *)
        opts="[number1]"
        ;;
    esac
  elif [ $COMP_CWORD -eq 3 ]; then
    case "$prev" in
      sin | cos | tan | log | ln | sqrt)
        opts=""
        ;;
      *)
        opts="+ - * / ^ %"
        ;;
    esac
  elif [ $COMP_CWORD -eq 4 ]; then
    opts="[number2]"
  fi

  COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
  return 0
}
complete -F _calculate_options calculate

# single line for creating and entering directory
mkdircd() {
  mkdir "$1" && cd "$_" || exit
}

# convert x to y
recast() {
  local arg1="$1"
  local arg2="$2"
  local arg3="$3"
  local arg4="$4"

  if [[ $1 == man2pdf ]]; then
    man -t "$2" | ps2pdf - "$3".pdf
  elif [[ $1 == txt2table ]]; then
    column -tns: "$2"
  elif [[ $1 == space2_ && $# -eq 1 ]]; then
    rename 'y/ /_/' -- *
  elif [[ $1 == space2_ && $# -eq 2 ]]; then
    rename 'y/ /_/' "$2"
  elif [[ $1 == json2yaml ]]; then
    jq -M . "$2" > "$3"
  elif [[ $1 == jpgpng2pdf || $1 == pngjpg2pdf ]]; then
    convert *.png *.jpg output.pdf
  elif [[ $1 == jpg2pdf ]]; then
    convert *.jpg output.pdf
  elif [[ $1 == png2pdf ]]; then
    convert *.png output.pdf
  elif [[ $1 == upper2lower ]]; then
    rename 'y/A-Z/a-z/' *
  elif [[ $1 == camel2_ ]]; then
    sed -r 's/([a-z]+)([A-Z][a-z]+)/\1_\l\2/g' "$2"
  elif [[ $1 == mpg2avi ]]; then
    if [[ "$2" != *.mpg ]]; then
        echo "Error: Input file must have the .mpg extension."
    fi
    if [[ "$3" != *.avi ]]; then
        echo "Error: Output file must have the .avi extension."
    fi
    ffmpeg -i "$2" "$3"
  elif [[ $1 == avi2mpg ]]; then
    if [[ "$2" != *.avi ]]; then
        echo "Error: Input file must have the .avi extension."
    fi
    if [[ "$3" != *.mpg ]]; then
        echo "Error: Output file must have the .mpg extension."
    fi
    ffmpeg -i "$2" "$3"
  elif [[ $1 == avi2flv ]]; then
      if [[ "$2" != *.avi ]]; then
          echo "Error: Input file must have the .avi extension."
      fi
      if [[ "$3" != *.flv ]]; then
          echo "Error: Output file must have the .flv extension."
      fi
      ffmpeg -i "$2" -ab 56 -ar 44100 -b 200 -r 15 -s 320x240 -f flv "$3"
  elif [[ $1 == avi2gif ]]; then
      if [[ "$2" != *.avi ]]; then
          echo "Error: Input file must have the .avi extension."
      fi
      if [[ "$3" != *.gif ]]; then
          echo "Error: Output file must have the .gif extension."
      fi
      ffmpeg -i "$2" -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=5 > "$3"
  elif [[ $1 == gif2webp ]]; then
      if [[ "$2" != *.gif ]]; then
          echo "Error: Input file must have the .gif extension."
      fi
      if [[ "$3" != *.webp ]]; then
          echo "Error: Output file must have the .webp extension."
      fi
      cwebp -q 80 "$2" -o "$3"
  elif [[ $1 == img2webp ]]; then
      if [[ "$2" != *.png && "$2" != *.jpg && "$2" != *.tiff && "$2" != *.bmp ]]; then
          echo "Error: Input file must have either the .png, .jpg, .tiff, or .bmp extension."
      fi
      if [[ "$3" != *.webp ]]; then
          echo "Error: Output file must have the .webp extension."
      fi
      cwebp -q 80 "$2" -o "$3"
  elif [[ "$arg1" == png2video ]]; then
    if [[ ! -d "$arg2" ]]; then
        echo "Error: Input directory does not exist."
    fi
    if [[ "$arg3" != *.mp4 ]]; then
        echo "Error: Output file must have the .mp4 extension."
    fi
    ffmpeg -framerate 1 -pattern_type glob -i "$arg2/*.png" -c:v libx264 -r 30 -pix_fmt yuv420p "$arg3"
  fi
}
_recast_autocomplete() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="man2pdf txt2table space2_ json2yaml jpgpng2pdf pngjpg2pdf jpg2pdf png2pdf upper2lower camel2_ mpg2avi avi2mpg avi2flv avi2gif gif2webp img2webp png2video"

    if [[ ${prev} == man2pdf ]]; then
        # complete filename for man2pdf
        COMPREPLY=( $(compgen -f -- "${cur}" ) )
    elif [[ ${prev} == txt2table ]]; then
        # complete filename for txt2table
        COMPREPLY=( $(compgen -f -- "${cur}" ) )
    elif [[ ${prev} == space2_ ]]; then
        # complete directories or files
        COMPREPLY=( $(compgen -A directory -- "${cur}" ) $(compgen -A file -- "${cur}" ) )
    elif [[ ${prev} == json2yaml ]]; then
        # complete filenames for json2yaml
        COMPREPLY=( $(compgen -f -- "${cur}" ) )
    elif [[ ${prev} == jpgpng2pdf || ${prev} == pngjpg2pdf || ${prev} == jpg2pdf || ${prev} == png2pdf ]]; then
        # complete filenames for image to pdf conversions
        COMPREPLY=( $(compgen -f -- "${cur}" ) )
    elif [[ ${prev} == upper2lower ]]; then
        # complete directories or files
        COMPREPLY=( $(compgen -A directory -- "${cur}" ) $(compgen -A file -- "${cur}" ) )
    elif [[ ${prev} == camel2_ ]]; then
        # complete filenames for camel2_
        COMPREPLY=( $(compgen -f -- "${cur}" ) )
    elif [[ ${prev} == mpg2avi || ${prev} == avi2mpg || ${prev} == avi2flv || ${prev} == avi2gif || ${prev} == gif2webp || ${prev} == img2webp ]]; then
        # complete filenames for video/image conversions
        COMPREPLY=( $(compgen -f -- "${cur}" ) )
    elif [[ ${prev} == png2video ]]; then
        # complete directories for png2video
        COMPREPLY=( $(compgen -d -- "${cur}" ) )
    else
        # complete options
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}" ) )
    fi
}

complete -F _recast_autocomplete recast

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
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local opts="passwd str_num_seq graph new_file user"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    return 0
  fi

  case "${COMP_WORDS[1]}" in
    passwd)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$(seq 1 100)" -- "${cur}"))
        return 0
      fi
      ;;
    str_num_seq)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        return 0
      fi
      if [[ ${COMP_CWORD} -eq 3 ]]; then
        COMPREPLY=($(compgen -W "$(seq 1 100)" -- "${cur}"))
        return 0
      fi
      if [[ ${COMP_CWORD} -eq 4 ]]; then
        return 0
      fi
      ;;
    graph)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        local opts="connection"
        COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
        return 0
      fi
      ;;
    new_file)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        return 0
      fi
      if [[ ${COMP_CWORD} -eq 3 ]]; then
        local opts="reduce_by_delimiter"
        COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
        return 0
      fi
      ;;
    user)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        return 0
      fi
      ;;
  esac
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
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [[ "$prev" == "search" ]]; then
    COMPREPLY=($(compgen -W "files google" -- "$cur"))
    return 0
  elif [[ "$prev" == "files" ]]; then
    _filedir
    return 0
  fi
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
_replace_slashes_back_completions() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "slashes back" -- "$cur") )
}

_replace_slashes_forth_completions() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "slashes forth" -- "$cur") )
}

_replace_string_completions() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "string" -- "$cur") )
}

_replace_tabs_spaces_completions() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "tabs spaces" -- "$cur") )
}

_replace_completions() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    case "$cur" in
        slashes)
            _replace_slashes_back_completions
            ;;
        string)
            _replace_string_completions
            ;;
        tabs)
            _replace_tabs_spaces_completions
            ;;
        *)
            COMPREPLY=( $(compgen -W "slashes string tabs" -- "$cur") )
            ;;
    esac
}

complete -F _replace_completions replace

check() {
  if [[ "$1" == syntax ]]; then
    find . -name '*.sh' -exec bash -n {} \;
  elif [[ "$1" == ssl_certificate_dates ]]; then
    if [ -z "$2" ]; then
      echo "Error: Website name not provided."
      return 1
    fi
    echo | openssl s_client -connect "$2":443 2> /dev/null \
      | openssl x509 -dates -noout
  fi
}
_check_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local options=("syntax" "ssl_certificate_dates")
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "${options[*]}" -- "$cur") )
  elif [ "$COMP_CWORD" -eq 2 ] && [ "${COMP_WORDS[1]}" == "ssl_certificate_dates" ]; then
    COMPREPLY=( $(compgen -f -- "$cur") )
  fi
}
complete -F _check_completions check

retain() {
  if [[ "$2" == only ]]; then
    echo "This command will delete all files except for '$1'. Are you sure you want to continue? (y/n)"
    read confirm
    if [[ "$confirm" == "y" ]]; then
      find . -type f ! -name "$1" -delete
    else
      echo "Aborted."
    fi
  fi
}
_retain_completions() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    # Complete file names for the first argument
    COMPREPLY=($(compgen -f -- "$cur"))
  elif [[ "$COMP_CWORD" -eq 2 ]]; then
    # Complete only keyword for the second argument
    COMPREPLY=($(compgen -W "only" -- "$cur"))
  fi
}

complete -F _retain_completions retain

compress() {
  if [[ "$1" == working_directory ]]; then
    tar -cf - . | pv -s "$(du -sb . | awk '{print $1}')" \
      | tar -xvf $1 > out.tar.gz
  fi
}
_compress() {
  local cur prev opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="working_directory"

  case "${prev}" in
    compress)
      COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
      return
      ;;
    *)
      ;;
  esac
}
complete -F _compress compress

schedule() {
  if [[ "$1" == script_or_command ]]; then
    ( (
      sleep "$3""$4"
      "$2"
    ) &)
  fi
}
_schedule() {
  local cur prev opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="script_or_command"

  if [[ $prev == "schedule" ]]; then
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
  elif [[ $prev == "script_or_command" ]]; then
    _command_names "${cur}"
  elif [[ $prev == "$3" ]]; then
    COMPREPLY=( $(compgen -W "seconds minutes hours days" -- "${cur}") )
  fi
}
complete -F _schedule schedule

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
_delete() {
  local cur prev opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="column row user"

  case "$prev" in
    delete)
      COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
      return
      ;;
    column)
      _filedir
      return
      ;;
    row)
      _filedir
      return
      ;;
    user)
      _users
      return
      ;;
    *)
      ;;
  esac
}
complete -F _delete delete

limit() {
  if [[ $1 == cpu_for_process ]]; then # set CPU utilization limit for process x
    if [[ $2 == "--help" ]]; then
      echo "Usage: limit cpu_for_process [niceness value] [command]"
      echo "  niceness value: a number in the range -20 to 19, where -20 is the highest priority and 19 is the lowest."
      echo "  command: the command to run with the specified CPU utilization limit."
    else
      nice -n "$2" "$3"
    fi
  fi
}
_limit_options() {
  local cur opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  opts="cpu_for_process"

  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}
complete -F _limit_options limit

replicate() {
  # replicate current terminal n times
  for i in $(seq 1 1 "$1"); do $(ps -o comm= -p "$(($(ps -o ppid= -p "$(($(ps -o sid= -p "$$")))")))") & done
}

stamp() {
  # stamp pdf with a text
  echo "$2" | enscript -B -f Courier-Bold16 -o- | ps2pdf - | pdftk "$1" stamp - output output.pdf
}
_stamp_options() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    COMPREPLY=( $(compgen -f -- "$cur") )
  elif [[ "$COMP_CWORD" -eq 2 ]]; then
    COMPREPLY=( $(compgen -W "\"Stamp text\"" -- "$cur") )
  fi
}
complete -F _stamp_options stamp

function modify() {
  # setting utility from the terminal
  if [[ $1 == "brightness" && $2 -ge 0 && $2 -le 100 ]]; then
    echo $(( $2 * 12000 / 100 )) | sudo tee /sys/class/backlight/intel_backlight/brightness
  else
    echo "Invalid brightness level. Please enter a value between 0 and 100."
  fi
}
_modify_options() {
  local cur prev opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="brightness"

  if [[ "$prev" == "modify" ]]; then
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
  fi

  if [[ "$prev" == "brightness" ]]; then
    COMPREPLY=( $(compgen -W "$(seq 0 100)" -- "$cur") )
    return 0
  fi
}
complete -F _modify_options modify

# For launching various applications not easily available in the command line
launch() {
  if [[ $1 == "cisco-anyconnect" ]]; then
    /opt/cisco/anyconnect/bin/vpnui
  else
    echo "Error: Invalid option. Valid options are: cisco-anyconnect."
  fi
}
_launch_completion() {
  local cur opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  opts="cisco-anyconnect"
  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
}
complete -F _launch_completion launch


#!/usr/bin/env bash

_U7_ARCHIVE_FORMATS=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .tbz .tbz2 .txz .tb2 .bz .bz2 .gz .zip .jar .Z .rar .7z .tar.lzma .xz .lzma .iso .img .dmg)

u7() {
  local verb="$1"
  shift

  case "$verb" in
    show)    _u7_show "$@" ;;
    make)    _u7_make "$@" ;;
    drop)    _u7_drop "$@" ;;
    convert) _u7_convert "$@" ;;
    move)    _u7_move "$@" ;;
    set)     _u7_set "$@" ;;
    run)     _u7_run "$@" ;;
    --help|-h|"") _u7_help ;;
    *)
      echo "Unknown verb: $verb"
      _u7_help
      return 1
      ;;
  esac
}

_u7_help() {
  cat << 'EOF'
Universal 7 (u7) - Human+AI CLI Standard

Usage: u7 <verb> <entity> [operator] [arguments]

Verbs:
  show     Observe/Search
  make     Create/Clone
  drop     Delete/Kill
  convert  Transform/Extract
  move     Relocate/Rename
  set      Modify/Config
  run      Execute/Control

Examples:
  u7 show ip external
  u7 show csv data.csv limit 10
  u7 make dir myproject
  u7 make password 16
  u7 drop file temp.txt
  u7 convert archive to files backup.tar.gz
  u7 convert png to jpg image.png
  u7 move file.txt to newname.txt
  u7 set text "old" to "new" in file.txt
  u7 run app vpn

Run 'u7 <verb> --help' for verb-specific help.
EOF
}

_u7_show() {
  local entity="$1"
  shift

  case "$entity" in
    ip)
      case "$1" in
        external) curl -s ifconfig.me && echo ;;
        internal)
          ifconfig | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v '^127\.' | head -1
          ;;
        connected) netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort -u ;;
        *) echo "Usage: u7 show ip <external|internal|connected>" ;;
      esac
      ;;

    csv)
      local file="$1"
      local limit="${3:-25}"
      if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      csvlook "$file" | head -n "$((limit + 1))"
      ;;

    json)
      local file="$1"
      local limit="${3:-10}"
      if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      jq ".[:$limit]" "$file"
      ;;

    line)
      local num="$1"
      local file="$2"
      sed -n "${num}p" "$file"
      ;;

    weather)
      curl -s "wttr.in/$1"
      ;;

    ssl)
      local domain="$1"
      if [[ -z "$domain" ]]; then
        echo "Usage: u7 show ssl <domain>"
        return 1
      fi
      echo | openssl s_client -connect "$domain":443 2>/dev/null | openssl x509 -dates -noout
      ;;

    files)
      case "$1" in
        match)
          local pattern="$2"
          local path="${3:-.}"
          grep -RnisI "$pattern" "$path"
          ;;
        modified) find . -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -20 | cut -d' ' -f2- ;;
        big) find . -type f -exec stat -f "%z %N" {} \; 2>/dev/null | sort -rn | head -10 ;;
        *) echo "Usage: u7 show files <match|modified|big> [pattern] [path]" ;;
      esac
      ;;

    diff)
      local file1="$1"
      local file2="$2"
      diff "$file1" "$file2"
      ;;

    info)
      case "$1" in
        cpu) cat /proc/cpuinfo 2>/dev/null || sysctl -a 2>/dev/null | grep -E 'machdep.cpu|hw.ncpu' ;;
        memory) free -h 2>/dev/null || vm_stat 2>/dev/null ;;
        disk) df -h ;;
        *) echo "Usage: u7 show info <cpu|memory|disk>" ;;
      esac
      ;;

    processes)
      case "$1" in
        running) ps aux ;;
        top_cpu) ps aux | sort -k3 -rn | head ;;
        top_memory) ps aux | sort -k4 -rn | head ;;
        *) echo "Usage: u7 show processes <running|top_cpu|top_memory>" ;;
      esac
      ;;

    port)
      lsof -i tcp:"$1"
      ;;

    usage)
      case "$1" in
        disk) du -sh "${2:-.}" ;;
        directories) du -h --max-depth "${2:-1}" 2>/dev/null | sort -hr || du -h -d "${2:-1}" | sort -hr ;;
        *) echo "Usage: u7 show usage <disk|directories> [path|depth]" ;;
      esac
      ;;

    network)
      ifconfig -a
      ;;

    git)
      case "$1" in
        authors) git log --format='%aN' | sort -u ;;
        branches)
          for k in $(git branch | sed 's/^..//'); do
            echo -e "$(git show --pretty=format:"%ci %cr" "$k" -- | head -n 1)\t$k"
          done | sort -r
          ;;
        *) echo "Usage: u7 show git <authors|branches>" ;;
      esac
      ;;

    definition)
      curl -s "dict://dict.org/d:$1"
      ;;

    functions)
      declare -F | awk '{print $3}' | grep -v "^_"
      ;;

    --help|-h)
      cat << 'EOF'
u7 show - Observe/Search

Usage: u7 show <entity> [arguments]

Entities:
  ip <external|internal|connected>
  csv <file> [limit N]
  json <file> [limit N]
  line <number> <file>
  weather <city>
  ssl <domain>
  files <match|modified|big> [pattern] [path]
  diff <file1> <file2>
  info <cpu|memory|disk>
  processes <running|top_cpu|top_memory>
  port <number>
  usage <disk|directories> [path|depth]
  network
  git <authors|branches>
  definition <word>
  functions
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 show --help' for usage"
      return 1
      ;;
  esac
}

_u7_make() {
  local entity="$1"
  shift

  case "$entity" in
    dir)
      mkdir -p "$1"
      ;;

    dircd)
      mkdir -p "$1" && cd "$1"
      ;;

    file)
      touch "$1"
      ;;

    password)
      local length="${1:-16}"
      LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
      echo
      ;;

    user)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 make user <username>"
        return 1
      fi
      sudo useradd "$1"
      ;;

    copy)
      local src="$1"
      local dst="$2"
      cp -r "$src" "$dst"
      ;;

    link)
      local src="$1"
      local dst="$2"
      ln -s "$src" "$dst"
      ;;

    archive)
      local output="$1"
      shift
      local format="${output##*.}"
      case "$format" in
        gz)
          if [[ "$output" == *.tar.gz ]]; then
            tar -czvf "$output" "$@"
          else
            gzip -c "$@" > "$output"
          fi
          ;;
        bz2)
          if [[ "$output" == *.tar.bz2 ]]; then
            tar -cjvf "$output" "$@"
          else
            bzip2 -c "$@" > "$output"
          fi
          ;;
        xz)
          if [[ "$output" == *.tar.xz ]]; then
            tar -cJvf "$output" "$@"
          else
            xz -c "$@" > "$output"
          fi
          ;;
        zip) zip -r "$output" "$@" ;;
        7z) 7z a "$output" "$@" ;;
        tar) tar -cvf "$output" "$@" ;;
        *) echo "Unsupported format: $format" ; return 1 ;;
      esac
      ;;

    sequence)
      local prefix="$1"
      local count="$2"
      local delim="${3:-_}"
      for i in $(seq 1 "$count"); do
        echo "${prefix}${delim}${i}"
      done
      ;;

    --help|-h)
      cat << 'EOF'
u7 make - Create/Clone

Usage: u7 make <entity> [arguments]

Entities:
  dir <path>                    Create directory
  dircd <path>                  Create and enter directory
  file <path>                   Create empty file
  password [length]             Generate random password (default: 16)
  user <username>               Create system user
  copy <src> <dst>              Copy file/directory
  link <src> <dst>              Create symbolic link
  archive <output> <files...>   Create archive (.tar.gz, .zip, .7z)
  sequence <prefix> <count>     Generate numbered sequence
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 make --help' for usage"
      return 1
      ;;
  esac
}

_u7_drop() {
  local entity="$1"
  shift

  case "$entity" in
    file)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 drop file <path>"
        return 1
      fi
      rm -i "$1"
      ;;

    dir)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 drop dir <path>"
        return 1
      fi
      rm -ri "$1"
      ;;

    dirs)
      if [[ "$1" == "empty" ]]; then
        find . -type d -empty -delete
        echo "Deleted empty directories"
      else
        echo "Usage: u7 drop dirs empty"
      fi
      ;;

    files)
      if [[ "$1" == "except" ]]; then
        local pattern="$2"
        echo "This will delete all files except '$pattern'. Continue? (y/n)"
        read -r confirm
        if [[ "$confirm" == "y" ]]; then
          find . -type f ! -name "$pattern" -delete
        else
          echo "Aborted."
        fi
      else
        echo "Usage: u7 drop files except <pattern>"
      fi
      ;;

    line)
      local num="$1"
      local file="$2"
      if [[ -z "$num" || -z "$file" ]]; then
        echo "Usage: u7 drop line <number> <file>"
        return 1
      fi
      sed -i'' "${num}d" "$file"
      ;;

    lines)
      if [[ "$1" == "blank" ]]; then
        local src="$2"
        local dst="$3"
        grep . "$src" > "$dst"
      else
        echo "Usage: u7 drop lines blank <input> <output>"
      fi
      ;;

    column)
      local num="$1"
      local file="$2"
      if [[ -z "$num" || -z "$file" ]]; then
        echo "Usage: u7 drop column <number> <file.csv>"
        return 1
      fi
      cut -d',' -f"$num" --complement "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      ;;

    duplicates)
      local file="$1"
      if [[ -z "$file" ]]; then
        echo "Usage: u7 drop duplicates <file>"
        return 1
      fi
      awk '!x[$0]++' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      ;;

    process)
      local pid="$1"
      if [[ -z "$pid" ]]; then
        echo "Usage: u7 drop process <pid>"
        return 1
      fi
      kill "$pid"
      ;;

    user)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 drop user <username>"
        return 1
      fi
      sudo deluser "$1"
      ;;

    --help|-h)
      cat << 'EOF'
u7 drop - Delete/Kill

Usage: u7 drop <entity> [arguments]

Entities:
  file <path>                   Delete file (with confirmation)
  dir <path>                    Delete directory (with confirmation)
  dirs empty                    Delete all empty directories
  files except <pattern>        Delete all files except pattern
  line <number> <file>          Delete line from file
  lines blank <input> <output>  Remove blank lines
  column <number> <file.csv>    Delete column from CSV
  duplicates <file>             Remove duplicate lines
  process <pid>                 Kill process
  user <username>               Delete system user
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 drop --help' for usage"
      return 1
      ;;
  esac
}

_u7_convert() {
  local entity="$1"
  shift

  case "$entity" in
    archive)
      if [[ "$1" != "to" || "$2" != "files" ]]; then
        echo "Usage: u7 convert archive to files <archive> [destination]"
        return 1
      fi
      shift 2
      local archive="$1"
      local dest="${2:-.}"

      if [[ ! -f "$archive" ]]; then
        echo "Archive not found: $archive"
        return 1
      fi

      local lowercase=$(echo "$archive" | tr '[:upper:]' '[:lower:]')

      case "$lowercase" in
        *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz|*.tbz|*.tbz2|*.txz|*.tb2)
          tar -xvf "$archive" -C "$dest" ;;
        *.bz|*.bz2)
          bzip2 -d -k "$archive" ;;
        *.gz)
          gunzip -c "$archive" > "$dest" ;;
        *.zip|*.jar)
          unzip "$archive" -d "$dest" ;;
        *.rar)
          unrar x "$archive" "$dest" ;;
        *.7z)
          7z x "$archive" "-o$dest" ;;
        *.tar.lzma)
          tar -xf "$archive" -C "$dest" --lzma ;;
        *.xz)
          unxz -c "$archive" > "$dest" ;;
        *.lzma)
          unlzma -c "$archive" > "$dest" ;;
        *.iso)
          sudo mount -o loop "$archive" "$dest" ;;
        *.img|*.dmg)
          hdiutil mount "$archive" -mountpoint "$dest" ;;
        *)
          echo "Unknown archive format: $archive"
          return 1
          ;;
      esac
      ;;

    files)
      if [[ "$1" != "to" || "$2" != "archive" ]]; then
        echo "Usage: u7 convert files to archive <output> <files...>"
        return 1
      fi
      shift 2
      _u7_make archive "$@"
      ;;

    png|jpg|jpeg|gif|bmp|tiff|webp)
      local from_fmt="$entity"
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 convert $from_fmt to <format> <input> [output]"
        return 1
      fi
      local to_fmt="$2"
      local input="$3"
      local output="${4:-${input%.*}.$to_fmt}"

      case "$to_fmt" in
        pdf)
          convert "$input" "$output"
          ;;
        webp)
          cwebp -q 80 "$input" -o "$output"
          ;;
        *)
          convert "$input" "$output"
          ;;
      esac
      ;;

    video)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 convert video to <format> <input> [output]"
        return 1
      fi
      local to_fmt="$2"
      local input="$3"
      local output="${4:-${input%.*}.$to_fmt}"

      case "$to_fmt" in
        gif)
          ffmpeg -i "$input" -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=5 > "$output"
          ;;
        *)
          ffmpeg -i "$input" "$output"
          ;;
      esac
      ;;

    json)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 convert json to yaml <input> [output]"
        return 1
      fi
      local to_fmt="$2"
      local input="$3"
      local output="${4:-${input%.*}.$to_fmt}"

      case "$to_fmt" in
        yaml|yml) yq -P < "$input" > "$output" ;;
        *) echo "Unsupported conversion: json to $to_fmt" ; return 1 ;;
      esac
      ;;

    case)
      if [[ "$1" == "upper" && "$2" == "to" && "$3" == "lower" ]]; then
        rename 'y/A-Z/a-z/' "${@:4}"
      elif [[ "$1" == "lower" && "$2" == "to" && "$3" == "upper" ]]; then
        rename 'y/a-z/A-Z/' "${@:4}"
      else
        echo "Usage: u7 convert case <upper|lower> to <lower|upper> <files...>"
      fi
      ;;

    spaces)
      if [[ "$1" == "to" && "$2" == "underscores" ]]; then
        if [[ -n "$3" ]]; then
          rename 'y/ /_/' "$3"
        else
          rename 'y/ /_/' -- *
        fi
      else
        echo "Usage: u7 convert spaces to underscores [file]"
      fi
      ;;

    math)
      local expr="$1"
      echo "scale=10; $expr" | bc -l
      ;;

    --help|-h)
      cat << 'EOF'
u7 convert - Transform/Extract

Usage: u7 convert <entity> to <format> <input> [output]

Entities:
  archive to files <archive> [dest]      Extract archive
  files to archive <output> <files...>   Create archive
  png to <jpg|webp|pdf> <input>          Convert image
  jpg to <png|webp|pdf> <input>          Convert image
  gif to webp <input>                    Convert GIF to WebP
  video to <format> <input>              Convert video
  json to yaml <input>                   Convert JSON to YAML
  case upper to lower <files...>         Rename to lowercase
  case lower to upper <files...>         Rename to uppercase
  spaces to underscores [file]           Replace spaces in filenames
  math "<expression>"                    Calculate math expression
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 convert --help' for usage"
      return 1
      ;;
  esac
}

_u7_move() {
  local src="$1"

  if [[ "$2" == "to" ]]; then
    local dst="$3"
    mv "$src" "$dst"
  elif [[ "$1" == "sync" ]]; then
    local src_dir="$2"
    if [[ "$3" == "to" ]]; then
      local dst_dir="$4"
      rsync -avz "$src_dir" "$dst_dir"
    else
      echo "Usage: u7 move sync <source> to <destination>"
      return 1
    fi
  elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat << 'EOF'
u7 move - Relocate/Rename

Usage: u7 move <source> to <destination>
       u7 move sync <source> to <destination>

Examples:
  u7 move file.txt to /backup/
  u7 move file.txt to newname.txt
  u7 move sync local/ to remote/
EOF
  else
    echo "Usage: u7 move <source> to <destination>"
    return 1
  fi
}

_u7_set() {
  local entity="$1"
  shift

  case "$entity" in
    text)
      local old="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 set text <old> to <new> in <file|directory>"
        return 1
      fi
      local new="$3"
      if [[ "$4" != "in" ]]; then
        echo "Usage: u7 set text <old> to <new> in <file|directory>"
        return 1
      fi
      local target="$5"

      if [[ -d "$target" ]]; then
        grep -rl "$old" "$target" | xargs sed -i'' "s/$old/$new/g"
      else
        sed -i'' "s/$old/$new/g" "$target"
      fi
      ;;

    slashes)
      if [[ "$1" == "back" ]]; then
        sed -i'' 's|/|\\|g' "$2"
      elif [[ "$1" == "forward" ]]; then
        sed -i'' 's|\\|/|g' "$2"
      else
        echo "Usage: u7 set slashes <back|forward> <file>"
      fi
      ;;

    tabs)
      if [[ "$1" == "to" && "$2" == "spaces" ]]; then
        find "${3:-.}" -type f -exec sed -i'' 's/\t/  /g' {} \;
      else
        echo "Usage: u7 set tabs to spaces [directory]"
      fi
      ;;

    perms)
      local mode="$1"
      local target="$2"
      chmod "$mode" "$target"
      ;;

    owner)
      local user="$1"
      local target="$2"
      chown "$user" "$target"
      ;;

    priority)
      local niceness="$1"
      shift
      nice -n "$niceness" "$@"
      ;;

    --help|-h)
      cat << 'EOF'
u7 set - Modify/Config

Usage: u7 set <entity> [arguments]

Entities:
  text <old> to <new> in <file>     Replace text in file(s)
  slashes <back|forward> <file>     Convert slashes
  tabs to spaces [directory]        Convert tabs to spaces
  perms <mode> <file>               Set file permissions
  owner <user> <file>               Set file owner
  priority <nice> <command>         Run with CPU priority
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 set --help' for usage"
      return 1
      ;;
  esac
}

_u7_run() {
  local entity="$1"
  shift

  case "$entity" in
    app)
      case "$1" in
        vpn|cisco-anyconnect)
          /opt/cisco/anyconnect/bin/vpnui
          ;;
        *)
          echo "Unknown app: $1"
          echo "Available: vpn"
          return 1
          ;;
      esac
      ;;

    job)
      local cmd="$1"
      if [[ "$2" != "in" ]]; then
        echo "Usage: u7 run job <command> in <time>"
        return 1
      fi
      local time="$3"
      local unit="${time//[0-9]/}"
      local value="${time//[^0-9]/}"

      case "$unit" in
        s) sleep "$value" && eval "$cmd" & ;;
        m) sleep "$((value * 60))" && eval "$cmd" & ;;
        h) sleep "$((value * 3600))" && eval "$cmd" & ;;
        *) echo "Use: Ns, Nm, or Nh (e.g., 5s, 10m, 1h)" ; return 1 ;;
      esac
      echo "Scheduled: '$cmd' in $time"
      ;;

    script)
      local script="$1"
      if [[ ! -f "$script" ]]; then
        echo "Script not found: $script"
        return 1
      fi
      bash "$script"
      ;;

    background)
      "$@" &
      echo "PID: $!"
      ;;

    check)
      case "$1" in
        syntax)
          find . -name '*.sh' -exec bash -n {} \;
          echo "Syntax check complete"
          ;;
        *)
          bash -n "$1"
          ;;
      esac
      ;;

    terminal)
      local count="${1:-1}"
      local term_cmd
      term_cmd=$(ps -o comm= -p "$(($(ps -o ppid= -p "$(($(ps -o sid= -p "$$")))")))")
      for _ in $(seq 1 "$count"); do
        $term_cmd &
      done
      ;;

    --help|-h)
      cat << 'EOF'
u7 run - Execute/Control

Usage: u7 run <entity> [arguments]

Entities:
  app <name>                  Launch application (vpn)
  job <cmd> in <time>         Schedule command (5s, 10m, 1h)
  script <path>               Execute shell script
  background <command>        Run command in background
  check syntax                Check all .sh files syntax
  check <file>                Check single file syntax
  terminal [count]            Open new terminal(s)
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 run --help' for usage"
      return 1
      ;;
  esac
}

_u7_completions() {
  local cur prev words cword
  _init_completion 2>/dev/null || {
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  }

  local verbs="show make drop convert move set run --help"

  case "$cword" in
    1)
      COMPREPLY=($(compgen -W "$verbs" -- "$cur"))
      ;;
    2)
      case "$prev" in
        show)
          COMPREPLY=($(compgen -W "ip csv json line weather ssl files diff info processes port usage network git definition functions --help" -- "$cur"))
          ;;
        make)
          COMPREPLY=($(compgen -W "dir dircd file password user copy link archive sequence --help" -- "$cur"))
          ;;
        drop)
          COMPREPLY=($(compgen -W "file dir dirs files line lines column duplicates process user --help" -- "$cur"))
          ;;
        convert)
          COMPREPLY=($(compgen -W "archive files png jpg jpeg gif video json case spaces math --help" -- "$cur"))
          ;;
        move)
          COMPREPLY=($(compgen -W "sync --help" -- "$cur"))
          _filedir
          ;;
        set)
          COMPREPLY=($(compgen -W "text slashes tabs perms owner priority --help" -- "$cur"))
          ;;
        run)
          COMPREPLY=($(compgen -W "app job script background check terminal --help" -- "$cur"))
          ;;
      esac
      ;;
    *)
      case "${words[1]}" in
        show)
          case "${words[2]}" in
            ip) COMPREPLY=($(compgen -W "external internal connected" -- "$cur")) ;;
            info) COMPREPLY=($(compgen -W "cpu memory disk" -- "$cur")) ;;
            processes) COMPREPLY=($(compgen -W "running top_cpu top_memory" -- "$cur")) ;;
            files) COMPREPLY=($(compgen -W "match modified big" -- "$cur")) ;;
            usage) COMPREPLY=($(compgen -W "disk directories" -- "$cur")) ;;
            git) COMPREPLY=($(compgen -W "authors branches" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        make)
          case "${words[2]}" in
            copy|link) _filedir ;;
          esac
          ;;
        drop)
          case "${words[2]}" in
            dirs) COMPREPLY=($(compgen -W "empty" -- "$cur")) ;;
            files) COMPREPLY=($(compgen -W "except" -- "$cur")) ;;
            lines) COMPREPLY=($(compgen -W "blank" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        convert)
          case "${words[2]}" in
            archive|files) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            png|jpg|jpeg|gif) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            case) COMPREPLY=($(compgen -W "upper lower" -- "$cur")) ;;
            spaces) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        set)
          case "${words[2]}" in
            slashes) COMPREPLY=($(compgen -W "back forward" -- "$cur")) ;;
            tabs) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        run)
          case "${words[2]}" in
            app) COMPREPLY=($(compgen -W "vpn" -- "$cur")) ;;
            check) COMPREPLY=($(compgen -W "syntax" -- "$cur")) ; _filedir ;;
            script) _filedir ;;
          esac
          ;;
      esac
      ;;
  esac
}

complete -F _u7_completions u7

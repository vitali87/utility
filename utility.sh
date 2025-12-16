#!/usr/bin/env bash

# Check if a command is available
_u7_require() {
  local cmd="$1"
  local msg="${2:-$cmd}"
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Required command '$cmd' not found."
    echo "Install it or run in 'nix develop' shell for full functionality."
    return 1
  fi
  return 0
}

# Escape special regex characters for literal sed replacement
_u7_escape_sed() {
  local str="$1"
  # Escape sed special chars: \ first, then . * [ ] ^ $ /
  str="${str//\\/\\\\}"  # Escape backslash
  str="${str//\//\\/}"    # Escape forward slash
  str="${str//./\\.}"     # Escape dot
  str="${str//\*/\\*}"    # Escape asterisk
  str="${str//\[/\\[}"    # Escape [
  str="${str//\]/\\]}"    # Escape ]
  str="${str//\^/\\^}"    # Escape ^
  str="${str//\$/\\$}"    # Escape $
  printf '%s' "$str"
}

u7() {
  local verb="$1"
  shift

  case "$verb" in
    show|sh)       _u7_show "$@" ;;
    make|mk)       _u7_make "$@" ;;
    drop|dr)       _u7_drop "$@" ;;
    convert|cv)    _u7_convert "$@" ;;
    move|mv)       _u7_move "$@" ;;
    set|st)        _u7_set "$@" ;;
    run|rn)        _u7_run "$@" ;;
    --help|-h|"")  _u7_help ;;
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
  sh (show)     Observe/Search
  mk (make)     Create/Clone
  dr (drop)     Delete/Kill
  cv (convert)  Transform/Extract
  mv (move)     Relocate/Rename
  st (set)      Modify/Config
  rn (run)      Execute/Control

Examples:
  u7 sh ip external
  u7 sh csv data.csv limit 10
  u7 mk dir myproject
  u7 mk password 16
  u7 dr file temp.txt
  u7 cv archive to files from backup.tar.gz yield ./
  u7 cv png to jpg from image.png yield image.jpg
  u7 mv file.txt to newname.txt
  u7 st text "old" to "new" in file.txt
  u7 rn job "echo done" in 5s

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
        *) echo "Usage: u7 sh ip <external|internal|connected>" ;;
      esac
      ;;

    csv)
      _u7_require qsv || return 1
      local file="$1"
      # $2 is "limit" keyword, $3 is the actual number
      local limit="${3:-25}"
      if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      # If user didn't provide "limit" keyword, use default
      if [[ "$2" == "limit" && -n "$3" ]]; then
        limit="$3"
      fi
      qsv table "$file" | head -n "$((limit + 1))"
      ;;

    json)
      local file="$1"
      # $2 is "limit" keyword, $3 is the actual number
      local limit="10"
      if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      # If user provided "limit" keyword, use their number
      if [[ "$2" == "limit" && -n "$3" ]]; then
        limit="$3"
      fi
      jq ".[:$limit]" "$file"
      ;;

    line)
      local num="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 sh line <number> from <file>"
        return 1
      fi
      local file="$3"
      sed -n "${num}p" "$file"
      ;;

    ssl)
      local domain="$1"
      if [[ -z "$domain" ]]; then
        echo "Usage: u7 sh ssl <domain>"
        return 1
      fi
      echo | openssl s_client -connect "$domain":443 2>/dev/null | openssl x509 -dates -noout
      ;;

    files)
      case "$1" in
        match)
          local pattern="$2"
          local path="."
          if [[ "$3" == "in" ]]; then
            path="${4:-.}"
          fi
          grep -RnisI "$pattern" "$path"
          ;;
        by)
          case "$2" in
            modified) find . -type f -exec stat -c "%Y %n" {} \; | sort -rn | head -20 | cut -d' ' -f2- ;;
            size) find . -type f -exec stat -c "%s %n" {} \; | sort -rn | head -10 ;;
            *) echo "Usage: u7 sh files by <modified|size>" ;;
          esac
          ;;
        *) echo "Usage: u7 sh files <match|by> [pattern|sort_type] [in <path>]" ;;
      esac
      ;;

    diff)
      local file1="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 sh diff <file1> to <file2>"
        return 1
      fi
      local file2="$3"
      diff "$file1" "$file2"
      ;;

    # TODO: Revisit cpu/memory/disk entity structure for granular queries (e.g. u7 sh cpu temp)
    cpu)
      cat /proc/cpuinfo 2>/dev/null || sysctl -a 2>/dev/null | grep -E 'machdep.cpu|hw.ncpu'
      ;;

    memory)
      free -h 2>/dev/null || vm_stat 2>/dev/null
      ;;

    disk)
      df -h
      ;;

    processes)
      case "$1" in
        running) ps aux ;;
        by)
          case "$2" in
            cpu) ps aux | sort -k3 -rn | head ;;
            memory) ps aux | sort -k4 -rn | head ;;
            *) echo "Usage: u7 sh processes by <cpu|memory>" ;;
          esac
          ;;
        *) echo "Usage: u7 sh processes <running|by> [cpu|memory]" ;;
      esac
      ;;

    port)
      lsof -i tcp:"$1"
      ;;

    usage)
      case "$1" in
        disk) du -sh "${2:-.}" ;;
        directories) du -h --max-depth "${2:-1}" | sort -hr ;;
        *) echo "Usage: u7 sh usage <disk|directories> [path|depth]" ;;
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
        *) echo "Usage: u7 sh git <authors|branches>" ;;
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
u7 sh (show) - Observe/Search

Usage: u7 sh <entity> [arguments]

Entities:
  ip <external|internal|connected>
  csv <file> [limit N]
  json <file> [limit N]
  line <number> from <file>
  ssl <domain>
  files <match|by> [pattern|sort_type] [in <path>]
  diff <file1> to <file2>
  cpu
  memory
  disk
  processes <running|by> [cpu|memory]
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
      echo "Run 'u7 sh --help' for usage"
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
        echo "Usage: u7 mk user <username>"
        return 1
      fi
      sudo useradd "$1"
      ;;

    copy)
      local src="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 mk copy <source> to <destination>"
        return 1
      fi
      local dst="$3"
      cp -r "$src" "$dst"
      ;;

    link)
      local src="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 mk link <source> to <destination>"
        return 1
      fi
      local dst="$3"
      ln -s "$src" "$dst"
      ;;

    archive)
      local output="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 mk archive <output> from <files...>"
        return 1
      fi
      shift 2
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
u7 mk (make) - Create/Clone

Usage: u7 mk <entity> [arguments]

Entities:
  dir <path>                    Create directory
  file <path>                   Create empty file
  password [length]             Generate random password (default: 16)
  user <username>               Create system user
  copy <src> to <dst>           Copy file/directory
  link <src> to <dst>           Create symbolic link
  archive <output> from <files...>  Create archive
  sequence <prefix> <count>     Generate numbered sequence
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 mk --help' for usage"
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
        echo "Usage: u7 dr file <path>"
        return 1
      fi
      rm -i "$1"
      ;;

    dir)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 dr dir <path>"
        return 1
      fi
      rm -ri "$1"
      ;;

    dirs)
      if [[ "$1" == "empty" ]]; then
        find . -type d -empty -delete
        echo "Deleted empty directories"
      else
        echo "Usage: u7 dr dirs empty"
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
        echo "Usage: u7 dr files except <pattern>"
      fi
      ;;

    line)
      local num="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 dr line <number> from <file>"
        return 1
      fi
      local file="$3"
      if [[ -z "$num" || -z "$file" ]]; then
        echo "Usage: u7 dr line <number> from <file>"
        return 1
      fi
      sed -i'' "${num}d" "$file"
      ;;

    lines)
      if [[ "$1" == "blank" && "$2" == "from" && "$4" == "yield" ]]; then
        local src="$3"
        local dst="$5"
        grep . "$src" > "$dst"
      else
        echo "Usage: u7 dr lines blank from <input> yield <output>"
      fi
      ;;

    column)
      local num="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 dr column <number> from <file.csv>"
        return 1
      fi
      local file="$3"
      if [[ -z "$num" || -z "$file" ]]; then
        echo "Usage: u7 dr column <number> from <file.csv>"
        return 1
      fi
      cut -d',' -f"$num" --complement "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      ;;

    duplicates)
      if [[ "$1" != "in" && "$1" != "from" ]]; then
        echo "Usage: u7 dr duplicates in|from <file>"
        return 1
      fi
      local file="$2"
      if [[ -z "$file" ]]; then
        echo "Usage: u7 dr duplicates in|from <file>"
        return 1
      fi
      awk '!x[$0]++' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      ;;

    process)
      local pid="$1"
      if [[ -z "$pid" ]]; then
        echo "Usage: u7 dr process <pid>"
        return 1
      fi
      kill "$pid"
      ;;

    user)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 dr user <username>"
        return 1
      fi
      sudo deluser "$1"
      ;;

    --help|-h)
      cat << 'EOF'
u7 dr (drop) - Delete/Kill

Usage: u7 dr <entity> [arguments]

Entities:
  file <path>                   Delete file (with confirmation)
  dir <path>                    Delete directory (with confirmation)
  dirs empty                    Delete all empty directories
  files except <pattern>        Delete all files except pattern
  line <number> from <file>     Delete line from file
  lines blank from <in> yield <out>  Remove blank lines
  column <number> from <file>  Delete column from CSV
  duplicates in|from <file>     Remove duplicate lines
  process <pid>                 Kill process
  user <username>               Delete system user
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 dr --help' for usage"
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
        echo "Usage: u7 cv archive to files from <archive> [yield <destination>]"
        return 1
      fi
      if [[ "$3" != "from" ]]; then
        echo "Usage: u7 cv archive to files from <archive> [yield <destination>]"
        return 1
      fi
      local archive="$4"
      local dest="."
      if [[ "$5" == "yield" ]]; then
          dest="$6"
      fi

      if [[ ! -f "$archive" ]]; then
        echo "Archive not found: $archive"
        return 1
      fi

      local lowercase=$(echo "$archive" | tr '[:upper:]' '[:lower:]')

      # Helper function to get output filename for single-file archives
      _get_output_file() {
        local archive="$1"
        local dest="$2"
        if [[ -d "$dest" ]]; then
          # Dest is directory, derive filename from archive
          local basename=$(basename "$archive")
          # Remove compression extension
          echo "$dest/${basename%.*}"
        else
          # Dest is a file path
          echo "$dest"
        fi
      }

      case "$lowercase" in
        *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz|*.tbz|*.tbz2|*.txz|*.tb2)
          tar -xvf "$archive" -C "$dest" ;;
        *.bz|*.bz2)
          bzip2 -d -k "$archive" ;;
        *.gz)
          local outfile=$(_get_output_file "$archive" "$dest")
          gunzip -c "$archive" > "$outfile" ;;
        *.zip|*.jar)
          unzip "$archive" -d "$dest" ;;
        *.rar)
          unrar x "$archive" "$dest" ;;
        *.7z)
          7z x "$archive" "-o$dest" ;;
        *.tar.lzma)
          tar -xf "$archive" -C "$dest" --lzma ;;
        *.xz)
          local outfile=$(_get_output_file "$archive" "$dest")
          unxz -c "$archive" > "$outfile" ;;
        *.lzma)
          local outfile=$(_get_output_file "$archive" "$dest")
          unlzma -c "$archive" > "$outfile" ;;
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
        echo "Usage: u7 cv files to archive yield <output> from <files...>"
        return 1
      fi
      if [[ "$3" != "yield" ]]; then
        echo "Usage: u7 cv files to archive yield <output> from <files...>"
        return 1
      fi
      local output="$4"
      if [[ "$5" != "from" ]]; then
        echo "Usage: u7 cv files to archive yield <output> from <files...>"
        return 1
      fi
      shift 5
      _u7_make archive "$output" from "$@"
      ;;

    png|jpg|jpeg|gif|bmp|tiff|webp)
      local from_fmt="$entity"
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 cv $from_fmt to <format> from <input> [yield <output>]"
        return 1
      fi
      local to_fmt="$2"
      if [[ "$3" != "from" ]]; then
        echo "Usage: u7 convert $from_fmt to <format> from <input> [yield <output>]"
        return 1
      fi
      local input="$4"
      local output="${input%.*}.$to_fmt"
      if [[ "$5" == "yield" ]]; then
          output="$6"
      fi

      case "$to_fmt" in
        pdf)
          convert "$input" "$output"
          ;;
        webp)
          if ! _u7_require cwebp; then
            echo "Falling back to ImageMagick for WebP conversion"
            convert "$input" "$output"
          else
            cwebp -q 80 "$input" -o "$output"
          fi
          ;;
        *)
          convert "$input" "$output"
          ;;
      esac
      ;;

    video)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 cv video to <format> from <input> [yield <output>]"
        return 1
      fi
      local to_fmt="$2"
      if [[ "$3" != "from" ]]; then
        echo "Usage: u7 convert video to <format> from <input> [yield <output>]"
        return 1
      fi
      local input="$4"
      local output="${input%.*}.$to_fmt"
      if [[ "$5" == "yield" ]]; then
          output="$6"
      fi

      case "$to_fmt" in
        gif)
          if ! _u7_require gifsicle; then
            echo "Falling back to ffmpeg-only conversion"
            ffmpeg -i "$input" "$output"
          else
            ffmpeg -i "$input" -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=5 > "$output"
          fi
          ;;
        *)
          ffmpeg -i "$input" "$output"
          ;;
      esac
      ;;

    json)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 cv json to yaml from <input> [yield <output>]"
        return 1
      fi
      local to_fmt="$2"
      if [[ "$3" != "from" ]]; then
        echo "Usage: u7 convert json to yaml from <input> [yield <output>]"
        return 1
      fi
      local input="$4"
      local output="${input%.*}.$to_fmt"
      if [[ "$5" == "yield" ]]; then
          output="$6"
      fi

      case "$to_fmt" in
        yaml|yml) yq -P < "$input" > "$output" ;;
        *) echo "Unsupported conversion: json to $to_fmt" ; return 1 ;;
      esac
      ;;

    case)
      if ! _u7_require rename "rename (perl-rename or prename)"; then
        echo "Hint: Install 'rename' package (perl-rename on Debian/Ubuntu, rename on others)"
        return 1
      fi
      if [[ "$1" == "upper" && "$2" == "to" && "$3" == "lower" ]]; then
        if [[ "$4" != "on" ]]; then
           echo "Usage: u7 cv case upper to lower on <files...>"
           return 1
        fi
        # Convert only basename to lowercase, preserve extension case
        rename 's/^(.*)(\.\w+)$/lc($1) . $2/e' "${@:5}"
      elif [[ "$1" == "lower" && "$2" == "to" && "$3" == "upper" ]]; then
        if [[ "$4" != "on" ]]; then
           echo "Usage: u7 cv case lower to upper on <files...>"
           return 1
        fi
        # Convert only basename to uppercase, preserve extension case
        rename 's/^(.*)(\.\w+)$/uc($1) . $2/e' "${@:5}"
      else
        echo "Usage: u7 cv case <upper|lower> to <lower|upper> on <files...>"
      fi
      ;;

    spaces)
      if ! _u7_require rename "rename (perl-rename or prename)"; then
        echo "Hint: Install 'rename' package (perl-rename on Debian/Ubuntu, rename on others)"
        return 1
      fi
      if [[ "$1" == "to" && "$2" == "underscores" ]]; then
        if [[ "$3" != "on" ]]; then
           echo "Usage: u7 cv spaces to underscores on <file>"
           return 1
        fi
        if [[ -n "$4" ]]; then
          rename 'y/ /_/' "$4"
        else
          rename 'y/ /_/' -- *
        fi
      else
        echo "Usage: u7 cv spaces to underscores on <file>"
      fi
      ;;

    --help|-h)
      cat << 'EOF'
u7 cv (convert) - Transform/Extract

Usage: u7 cv <entity> to <format> from <input> [yield <output>]

Entities:
  archive to files from <archive> [yield <dest>]  Extract archive
  files to archive yield <output> from <files...>   Create archive
  png to <jpg|webp|pdf> from <input>     Convert image
  jpg to <png|webp|pdf> from <input>     Convert image
  gif to webp from <input>               Convert GIF to WebP
  video to <format> from <input>         Convert video
  json to yaml from <input>              Convert JSON to YAML
  case upper to lower on <files...>      Rename to lowercase
  case lower to upper on <files...>      Rename to uppercase
  spaces to underscores on <file>        Replace spaces in filenames
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 cv --help' for usage"
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
      echo "Usage: u7 mv sync <source> to <destination>"
      return 1
    fi
  elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat << 'EOF'
u7 mv (move) - Relocate/Rename

Usage: u7 mv <source> to <destination>
       u7 mv sync <source> to <destination>

Examples:
  u7 mv file.txt to /backup/
  u7 mv file.txt to newname.txt
  u7 mv sync local/ to remote/
EOF
  else
    echo "Usage: u7 mv <source> to <destination>"
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
        echo "Usage: u7 st text <old> to <new> in <file|directory>"
        return 1
      fi
      local new="$3"
      if [[ "$4" != "in" ]]; then
        echo "Usage: u7 st text <old> to <new> in <file|directory>"
        return 1
      fi
      local target="$5"

      # Escape special regex characters for literal matching
      local old_escaped=$(_u7_escape_sed "$old")
      local new_escaped=$(_u7_escape_sed "$new")

      if [[ -d "$target" ]]; then
        # Use grep with -F for literal string matching, then sed for replacement
        grep -rlF "$old" "$target" 2>/dev/null | while IFS= read -r file; do
          sed -i'' "s/$old_escaped/$new_escaped/g" "$file"
        done
      else
        sed -i'' "s/$old_escaped/$new_escaped/g" "$target"
      fi
      ;;

    slashes)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 st slashes to <back|forward> in <file>"
        return 1
      fi
      local direction="$2"
      if [[ "$3" != "in" ]]; then
        echo "Usage: u7 st slashes to <back|forward> in <file>"
        return 1
      fi
      local file="$4"
      if [[ "$direction" == "back" ]]; then
        sed -i'' 's|/|\\|g' "$file"
      elif [[ "$direction" == "forward" ]]; then
        sed -i'' 's|\\\\|/|g' "$file"
      else
        echo "Usage: u7 st slashes to <back|forward> in <file>"
        return 1
      fi
      ;;

    tabs)
      if [[ "$1" == "to" && "$2" == "spaces" ]]; then
        if [[ "$3" != "in" ]]; then
            echo "Usage: u7 st tabs to spaces in <directory>"
            return 1
        fi
        find "${4:-.}" -type f -exec sed -i'' 's/\t/  /g' {} \;
      else
        echo "Usage: u7 st tabs to spaces in <directory>"
      fi
      ;;

    perms)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 st perms to <mode> on <file>"
        return 1
      fi
      local mode="$2"
      if [[ "$3" != "on" ]]; then
        echo "Usage: u7 st perms to <mode> on <file>"
        return 1
      fi
      local target="$4"
      chmod "$mode" "$target"
      ;;

    owner)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 st owner to <user> on <file>"
        return 1
      fi
      local user="$2"
      if [[ "$3" != "on" ]]; then
        echo "Usage: u7 st owner to <user> on <file>"
        return 1
      fi
      local target="$4"
      chown "$user" "$target"
      ;;

    --help|-h)
      cat << 'EOF'
u7 st (set) - Modify/Config

Usage: u7 st <entity> [arguments]

Entities:
  text <old> to <new> in <file>           Replace text in file(s)
  slashes to <back|forward> in <file>     Convert slashes
  tabs to spaces in <directory>           Convert tabs to spaces
  perms to <mode> on <file>           Set file permissions
  owner to <user> on <file>           Set file owner
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 st --help' for usage"
      return 1
      ;;
  esac
}

_u7_run() {
  local entity="$1"
  shift

  case "$entity" in
    app)
      echo "Error: 'u7 rn app' is not implemented."
      echo "To run applications, use their direct commands or add custom handlers."
      return 1
      ;;

    job)
      local cmd="$1"
      if [[ "$2" != "in" ]]; then
        echo "Usage: u7 rn job <command> in <time>"
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

    priority)
      local niceness="$1"
      shift
      nice -n "$niceness" "$@"
      ;;

    --help|-h)
      cat << 'EOF'
u7 rn (run) - Execute/Control

Usage: u7 rn <entity> [arguments]

Entities:
  job <cmd> in <time>         Schedule command (5s, 10m, 1h)
  script <path>               Execute shell script
  background <command>        Run command in background
  priority <nice> <command>   Run with CPU priority
  check syntax                Check all .sh files syntax
  check <file>                Check single file syntax
  terminal [count]            Open new terminal(s)
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 rn --help' for usage"
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

  local verbs="show sh make mk drop dr convert cv move mv set st run rn --help"

  case "$cword" in
    1)
      COMPREPLY=($(compgen -W "$verbs" -- "$cur"))
      ;;
    2)
      case "$prev" in
        show|sh)
          COMPREPLY=($(compgen -W "ip csv json line ssl files diff cpu memory disk processes port usage network git definition functions --help" -- "$cur"))
          ;;
        make|mk)
          COMPREPLY=($(compgen -W "dir file password user copy link archive sequence --help" -- "$cur"))
          ;;
        drop|dr)
          COMPREPLY=($(compgen -W "file dir dirs files line lines column duplicates process user --help" -- "$cur"))
          ;;
        convert|cv)
          COMPREPLY=($(compgen -W "archive files png jpg jpeg gif video json case spaces --help" -- "$cur"))
          ;;
        move|mv)
          COMPREPLY=($(compgen -W "sync --help" -- "$cur"))
          _filedir
          ;;
        set|st)
          COMPREPLY=($(compgen -W "text slashes tabs perms owner --help" -- "$cur"))
          ;;
        run|rn)
          COMPREPLY=($(compgen -W "job script background priority check terminal --help" -- "$cur"))
          ;;
      esac
      ;;
    *)
      case "${words[1]}" in
        show|sh)
          case "${words[2]}" in
            ip) COMPREPLY=($(compgen -W "external internal connected" -- "$cur")) ;;
            processes) COMPREPLY=($(compgen -W "running by" -- "$cur")) ;;
            files) COMPREPLY=($(compgen -W "match by" -- "$cur")) ;;
            usage) COMPREPLY=($(compgen -W "disk directories" -- "$cur")) ;;
            git) COMPREPLY=($(compgen -W "authors branches" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        make|mk)
          case "${words[2]}" in
            copy|link) _filedir ;;
          esac
          ;;
        drop|dr)
          case "${words[2]}" in
            dirs) COMPREPLY=($(compgen -W "empty" -- "$cur")) ;;
            files) COMPREPLY=($(compgen -W "except" -- "$cur")) ;;
            lines) COMPREPLY=($(compgen -W "blank" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        convert|cv)
          case "${words[2]}" in
            archive|files) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            png|jpg|jpeg|gif) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            case) COMPREPLY=($(compgen -W "upper lower" -- "$cur")) ;;
            spaces) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        set|st)
          case "${words[2]}" in
            slashes) COMPREPLY=($(compgen -W "back forward" -- "$cur")) ;;
            tabs) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            perms|owner) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
            *) _filedir ;;
          esac
          ;;
        run|rn)
          case "${words[2]}" in
            check) COMPREPLY=($(compgen -W "syntax" -- "$cur")) ; _filedir ;;
            script) _filedir ;;
          esac
          ;;
      esac
      ;;
  esac
}

if [[ $- == *i* ]]; then
  complete -F _u7_completions u7
fi

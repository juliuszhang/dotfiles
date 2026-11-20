# JDK 使用 Homebrew 安装；切换同时更新 JAVA_HOME、PATH 和命令缓存。
_use_jdk() {
  local version="$1"
  local brew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
  local java_home
  case "$version" in
    25) java_home="$brew_prefix/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home" ;;
    *) print -u2 "未配置 JDK $version。"; return 1 ;;
  esac

  if [[ ! -x "$java_home/bin/java" || ! -x "$java_home/bin/javac" ]]; then
    print -u2 "JDK $version 尚未安装，请执行：brew install openjdk@$version"
    return 1
  fi
  # openjdk 是滚动版本；确认其实际主版本，避免未来错误地切到其他版本。
  if ! /usr/bin/grep -Eq "^JAVA_VERSION=\"${version}([.\"+_-])" "$java_home/release"; then
    print -u2 "该 JDK 目录的版本不是 $version：$java_home"
    return 1
  fi

  local entry
  local -a next_path
  for entry in "${path[@]}"; do
    if [[ "$entry" != "$java_home/bin" && ( -z "$JAVA_HOME" || "$entry" != "$JAVA_HOME/bin" ) ]]; then
      next_path+=("$entry")
    fi
  done
  export JAVA_HOME="$java_home"
  path=("$JAVA_HOME/bin" "${next_path[@]}")
  export PATH
  rehash
}

alias jdk25='_use_jdk 25'
alias jdklts='_use_jdk 25'

# 默认 JDK（最新 LTS 25）在 ~/.zshenv 中设置，脚本和 zsh -c 也会使用。

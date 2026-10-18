# Dotfiles

用 chezmoi 管理当前 macOS 开发环境配置。

| 配置 | 应用位置 |
| --- | --- |
| Neovim（含插件锁定文件、Lua 模块和 snippets） | `~/.config/nvim/` |
| Zsh | `~/.zshrc`、`~/.zprofile`、`~/.config/zsh/java.zsh` |
| Starship 提示符 | `~/.config/starship.toml` |
| Ghostty | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |

Neovim 插件缓存、shell 历史、日志、备份和本机密钥不在管理范围内。Neovim 的快捷键和语言服务安装说明见 [Neovim README](dot_config/nvim/README.md)。

## 在新的 Mac 上使用

安装 Homebrew 后，安装配置用到的工具：

```sh
brew install chezmoi gitleaks gh neovim ripgrep starship fzf eza bat \
  zsh-autosuggestions zsh-syntax-highlighting openjdk@25
brew install --cask ghostty font-jetbrains-mono-nerd-font
```

Neovim 需要 0.12+，若 Homebrew 的版本不足，请安装符合要求的版本。Ghostty 配置使用 macOS Liquid Glass 效果，需要支持该选项的系统与 Ghostty 版本。当前 Zsh 配置使用 Apple Silicon Homebrew 的 `/opt/homebrew` 路径。

仓库为私有，先完成 GitHub 登录，再初始化：

```sh
gh auth login
gh auth setup-git
chezmoi init https://github.com/juliuszhang/dotfiles.git
git -C "$(chezmoi source-path)" config core.hooksPath .githooks
chezmoi diff
chezmoi apply
```

在当前机器上，chezmoi 源目录是 `~/Workspace/dotfiles`，已写入本机的 `~/.config/chezmoi/chezmoi.toml`；新机器默认使用 chezmoi 自己的源目录。

## 本机敏感配置

API 密钥仅保存在 `~/.config/zsh/local.zsh`，由 `.zshrc` 按原有顺序加载；该文件不进入仓库，也不由 chezmoi 覆盖。新机器按需建立：

```sh
mkdir -p ~/.config/zsh
(umask 077; cp -n "$(chezmoi source-path)/examples/zsh-local.example.zsh" ~/.config/zsh/local.zsh)
chmod 600 ~/.config/zsh/local.zsh
${EDITOR:-vi} ~/.config/zsh/local.zsh
```

只在本机填写真实值。仓库里的示例不含密钥；`.chezmoiignore` 和 `.gitignore` 同时排除本机文件、备份和常见敏感文件。

## 日常修改与同步

直接修改应用的配置后，将当前受管理的文件重新导入，再检查提交内容：

```sh
chezmoi re-add
chezmoi git -- diff
chezmoi git -- add -A
chezmoi git -- commit -m "Update dotfiles"
chezmoi git -- push
```

新增文件用 `chezmoi add <文件路径>`。也可以用 `chezmoi edit <文件路径>` 修改源配置，再执行 `chezmoi diff` 和 `chezmoi apply`。

从 GitHub 拉取并应用配置：

```sh
chezmoi update
```

本仓库启用提交前暂存区扫描和推送前全部 Git 历史扫描，使用 Gitleaks 默认规则和额外的 shell 密钥规则，检测日志对密钥脱敏。手动扫描：

```sh
chezmoi cd
gitleaks dir --config .gitleaks.toml --redact --no-banner .
gitleaks git --config .gitleaks.toml --log-opts="--all" --redact --no-banner .
```

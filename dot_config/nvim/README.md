# Neovim 配置

个人 Neovim 配置，使用内置 `vim.pack` 管理插件，`nvim-pack-lock.json` 记录插件版本。
语言服务复用 `nvim-lspconfig` 的默认配置，通过内置 `vim.lsp.config()` 定制、`vim.lsp.enable()` 启用。

## 环境

- Neovim 0.12+、Git。
- `ripgrep` 用于文件和全文搜索。
- 本机 JDK 使用 Homebrew 安装，通过 zsh 的 `jdk25` / `jdk27` alias 切换；`jdklts` 切回 JDK 25 LTS。
- 默认使用 JDK 25；Maven 使用 `JAVA_HOME` 指定的 JDK，`mvn -version` 可检查当前版本。
- IntelliJ 语言服务自动下载官方服务器包，使用包内 JBR。项目分析优先使用项目指定 JDK；未指定时采用有效的 `JAVA_HOME`，否则尝试 Homebrew JDK 25 / 21。
- Maven 项目需要可用的 `mvn`（可通过 `brew install maven` 安装）或项目提供的 Maven Wrapper；只有服务器自带 JBR 并不足以完成 Maven 导入。用 `mvn -version` 检查其运行 JDK 与项目要求一致。
- 使用图标时建议选择 Nerd Font 终端字体。
- Tree-sitter 解析器安装需要对应的编译工具和插件要求的构建依赖。

## 安装

将仓库放到 `~/.config/nvim`（已有配置请先备份）。首次启动 Neovim 会安装缺失的插件。

打开 `:Mason`，按需要安装 `lua-language-server`、`typescript-language-server` 和 `vue-language-server`，
以及格式化工具 `stylua`、`prettierd`。
JS/TS/Vue 语言服务器还需要可用的 Node.js 环境。Vue 支持需同时安装 TypeScript 和 Vue 两个语言服务器。
Mason 将可执行文件加入 PATH，配置仅启用命令已可用的服务器；安装完成后重新打开 Neovim。
即使项目内已有 TypeScript 语言服务器，也需要先通过 Mason 等方式在 PATH 中提供该命令，才能启用 `ts_ls`。缺少 TS 服务时不会单独启用 Vue 服务。

执行 `:TSInstallConfigured` 安装配置使用的语法解析器。

插件更新命令：`:lua vim.pack.update()`。

## 配置结构

| 文件 | 内容 |
| --- | --- |
| `init.lua` | 配置入口 |
| `lua/config/options.lua` | 基础选项、Leader |
| `lua/config/plugins.lua` | 插件声明 |
| `lua/config/ui.lua` | 主题、状态栏、标签、文件树 |
| `lua/config/editing.lua` | 编辑、搜索、跳转快捷键 |
| `lua/config/lsp.lua` | LSP 默认配置定制与启用、原生补全、诊断、语言服务快捷键 |
| `lua/config/java.lua` | IntelliJ LSP 原生能力与项目 JDK |
| `ftplugin/java.lua` | Java 缩进 |
| `lua/config/treesitter.lua` | 语法高亮和解析器安装命令 |
| `stylua.toml` | 本配置的 Lua 格式（2 空格缩进） |

## 语言服务

`nvim-lspconfig` 提供服务器默认配置，不负责安装服务器；安装由 Mason 管理。使用 Neovim 内置的新接口，不使用旧的 `require("lspconfig").xxx.setup()`。

- Lua：保留配置目录的项目识别，以及 Neovim 配置专用的 LuaJIT、`vim` 全局变量和运行时库设置。
- JavaScript/TypeScript：保留原有项目根目录规则，并加载 Vue 的 TypeScript 插件；启动命令和附加代码操作复用上游。上游会优先使用项目内安装的 TypeScript 语言服务器，否则使用 PATH 中的版本。
- Vue：完整复用上游默认配置，包括模板/样式服务、TS 请求转发和连接重试；脚本支持由 `ts_ls` 配合完成。
- Java/Kotlin：由 [intellij-lsp.nvim](https://github.com/JetBrains/intellij-lsp.nvim) 启动，客户端名称为 `intellij`。启动时加载插件，自动识别构建文件并导入项目；不再安装或启动 JDT LS。
- 首次打开项目时，按插件提示阅读并接受服务器协议、选择地区和数据共享选项，再通过 `:IntellijLspLicense` 登录或选择试用。配置不预先接受协议或开启试用。官方标注插件为实验性；每个服务器构建提供 30 天试用，之后需要 IDEA Ultimate 订阅。
- 用 `:checkhealth intellij-lsp` 检查服务器与授权，`:IntellijLspOutput` 查看导入日志。服务独占约需 2 GB 可用内存，构建导入时需要更多。
- Java/Kotlin 使用插件自带的补全、参数提示、LSP 折叠、文件模板和格式化；已移除 Blink、friendly-snippets 及先前的 Blink 适配包装。服务器返回的 snippet 补全仍由 `vim.snippet` 展开。
- `grr` 统一使用 Telescope 查找引用，关闭 IntelliJ 的默认引用映射；`<leader>F` 直接使用 IntelliJ 格式化。`<leader>o/O` 继续用 Telescope，以保留项目符号/全部符号两种搜索范围。
- `keymaps=false` 保留自定义 Leader 布局，避免 `<leader>ws` 与 `<leader>w` 的前缀冲突。回车统一在 `editing.lua` 中处理：有菜单时确认候选，无菜单时保留 autopairs 的括号内换行。插件自动补全及参数提示保持开启。
- Java/Kotlin 服务连接后使用 LSP 折叠，其他语言以及服务不可用时保留 Tree-sitter；Tree-sitter 继续提供语法高亮和缩进。切换文件、分屏或后台连接时按窗口同步折叠来源。
- Conform 保留用于其他语言的 stylua/prettierd；Telescope 保留文件、全文和符号搜索；Fugitive 保留现有 blame，插件 Git 面板不能等价替代它。Catppuccin 和其他编辑/UI 插件保留。没有 nvim-dap，运行/调试功能仍关闭。
- `<leader>i` 使用标准 `source.organizeImports` 代码操作；`<leader>o` 过滤 `jar:` / `jrt:` 依赖符号，`<leader>O` 保留全部符号。没有构建文件或 Git 根目录的独立 Java 文件可能无法自动启动此服务。

用 `:checkhealth vim.lsp` 检查配置状态，或用 `:lua =vim.lsp.get_clients({ bufnr = 0 })` 查看当前文件连接的服务。

## 常用快捷键

Leader 为 **空格**，以下大写字母需要 Shift。

| 快捷键 | 功能 |
| --- | --- |
| `<leader>ff` | 搜索当前文件所在项目的文件，包含隐藏文件 |
| `<leader>fg` | 搜索当前文件所在项目的文本，包含隐藏文件 |
| `<leader>fF` / `<leader>fG` | 按当前工作目录搜索文件 / 文本 |
| `<Esc>` | 清除搜索高亮 |
| `<leader>s` / `<leader>v` | 上下 / 左右分屏，新窗口出现在下方 / 右侧 |
| `H` / `L` | 前一个 / 后一个文件标签 |
| `<leader>w` / `<leader>W` | 关闭当前 / 其他文件标签，保留布局和未保存文件 |
| `gd` | 查找定义 |
| `gri` | 查找实现（原生 `gi` 保持不变） |
| `grr` | 查找引用 |
| `<leader>o` | 搜索工作区符号，Java 过滤第三方和 JDK 类 |
| `<leader>O` | 搜索全部工作区符号，包含第三方和 JDK 类 |
| `<leader>ds` | 搜索当前文件符号 |
| `<leader>rn` | 重命名符号 |
| `<leader>ca` | 代码操作 |
| `<leader>F` | 格式化当前文件：Lua 用 stylua，JS/TS/JSON/Markdown 用 prettierd，其他回退到语言服务 |
| `<leader>i` | 整理 Java import |

语言服务相关快捷键在 LSP 连接当前文件后生效。补全使用 Neovim 原生菜单：Enter 确认候选，Ctrl+n / Ctrl+p 选择，Ctrl+e 取消；LSP 片段中的 Tab / Shift+Tab 跳转占位符。
Java/Kotlin 由 IntelliJ 自动触发标识符补全和参数提示；Lua/JS/TS/Vue 使用 Neovim 原生自动补全，插入模式 Ctrl+s 查看参数提示。
移除 Blink 后，不再混合显示路径、buffer 单词和本地 snippets；仍可用原生 Ctrl+x Ctrl+f 补路径、Ctrl+x Ctrl+n 补当前文件单词、Ctrl+x Ctrl+o 手动请求 LSP。
`friendly-snippets` 已卸载；不再使用的 Mermaid 片段归档在 chezmoi 仓库的 `examples/neovim/mermaid.json`，不部署到 Neovim 配置目录。Java/Kotlin 新建空文件使用 IntelliJ 文件模板。

搜索优先定位到当前文件的 Git 仓库根目录；无 Git 时使用最近的构建标记目录，否则使用文件所在目录。
编辑 Neovim 自身配置时固定搜索 `~/.config/nvim`；无文件或特殊窗口则使用当前工作目录。
文件和全文搜索均遵循 `.gitignore`，排除 `.git` 内部数据；`fF` / `fG` 可配合 `:cd` 指定搜索范围。

回到编辑器或切回文件时自动检查磁盘更新，只自动重载没有未保存修改的文件。
普通搜索忽略大小写，包含大写字母时区分大小写。
命令行和搜索使用底部原生输入栏。`:s` 替换实时预览，复制时短暂高亮复制范围。
有未保存修改时 `:q` 会阻止退出；先用 `:w` 保存，或用 `:q!` 放弃修改。
Tree-sitter 负责缩进；折叠优先使用已连接的 IntelliJ 服务，其余使用 Tree-sitter：`zM` 全部折叠、`za` 切换当前、`zR` 全部展开，打开文件时默认展开。
当前插件不依赖 Python/Ruby/Perl/Node 外部接口，因此关闭对应 provider。

## tmux 配合

配置位于 `~/.tmux.conf`，Prefix 保持为 `Ctrl-a`。

| 按键 | 功能 |
| --- | --- |
| Prefix `-` / `\|` | 上下 / 左右分屏，继承当前目录 |
| Prefix `c` | 在当前窗格目录新建窗口 |
| Prefix `h/j/k/l` | 切换窗格，切换后输入立即交给应用 |
| Prefix `H/J/K/L` | 调整窗格大小，可连续按 |
| Prefix `[`，然后 `v`、`y` | 进入 vi 复制模式、选择、复制到 macOS 剪贴板 |
| Prefix `r` | 重载 tmux 配置 |

支持鼠标选择窗格、拖动边框和滚轮回看；复制模式下 Enter 或鼠标拖选结束也会复制。
Ghostty 真彩色与焦点事件会传递给 Neovim，保留扩展按键协议，历史容量为每窗格 50000 行。
窗口和窗格从 1 开始编号，关闭窗口后自动重新编号；开启 OSC 52，程序（包括 SSH 中的 Neovim）可写入系统剪贴板。
状态栏使用 Catppuccin Mocha 配色（与 Neovim 主题一致，无需插件）；按下 Prefix 后左侧会话名由紫色变为红色。
终端类型和历史容量对新建窗格生效；Neovim 配置在重新启动编辑器后生效。

## 更新记录

- 2026-10-29：归档不再加载的 Mermaid 片段，删除重复的多光标映射、空 Tree-sitter 初始化和内置/插件默认设置；K 使用 Neovim 原生悬浮文档映射。

- 2026-09-25：同步导航、LSP 项目识别及重复配置清理，补充搜索和 tmux 体验设置。
- 2026-10-09：删除残留插件 hop.nvim / vim-easymotion，新增 conform.nvim，blink.cmp 改用 Rust 模糊匹配。
- 2026-10-09：补充 Tree-sitter 缩进/折叠、常用选项、复制高亮，关闭外部插件接口，Java 缩进移入 `ftplugin/java.lua`；tmux RGB 设置改为不写死下标并增加 `xterm-256color`。
- 2026-10-29：用 IntelliJ LSP 替换 JDT LS；随后移除 Blink/friendly-snippets，启用插件原生补全、参数提示、引用、折叠和文件模板，保留自定义快捷键。
- 2026-10-18：引入 `nvim-lspconfig`，复用语言服务器默认配置和 Vue 请求转发，保留 Lua/TS 项目识别及 Java 集成；补充 Vue 的 TS 依赖检查。

修改前建议先备份 `~/.tmux.conf` 与 `~/.config/nvim/`，恢复时退出 Neovim 后复制回原位并重载 tmux 配置。

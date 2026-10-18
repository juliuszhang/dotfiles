-- 语言服务与补全配置。
-- LSP 让编辑器向语言服务器请求诊断、定义、重命名、格式化等能力。
-- Mason 安装服务器并加入 PATH；nvim-lspconfig 提供默认配置；vim.lsp 定制/启用；blink.cmp 展示补全。
-- 本文件配置 Lua、JavaScript/TypeScript、Vue；Java 由 ftplugin/java.lua 单独启动。
-- 快捷键 <leader> 是空格；大写 D/F/K 等需要 Shift，grr 是依次按 g、r、r。

-- 统一配置警告、错误等诊断信息的显示方式。
vim.diagnostic.config({
  -- 在行尾显示诊断文字，间隔 2 个空格；存在多个来源时显示来源名。
  virtual_text = { spacing = 2, source = "if_many" },
  -- 左侧标记栏显示诊断符号。
  signs = true,
  -- 给问题代码加下划线。
  underline = true,
  -- 按严重程度排序诊断。
  severity_sort = true,
  -- 插入模式中暂缓刷新诊断，减少输入时的干扰。
  update_in_insert = false,
  -- 诊断浮窗使用圆角边框，并展示诊断来源。
  float = { border = "rounded", source = true },
})
-- 空格 Shift+d：浮窗查看当前行诊断。
vim.keymap.set("n", "<leader>D", function()
  vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Line diagnostics" })
-- 按文件类型选择格式化工具；未列出的类型（如 Java）回退到语言服务格式化。
-- stylua、prettierd 通过 :MasonInstall 安装，Mason 会把它们加入 PATH。
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    javascript = { "prettierd" },
    javascriptreact = { "prettierd" },
    typescript = { "prettierd" },
    typescriptreact = { "prettierd" },
    json = { "prettierd" },
    markdown = { "prettierd" },
  },
  default_format_opts = { lsp_format = "fallback" },
})
-- 空格 Shift+f：格式化当前 buffer。
vim.keymap.set("n", "<leader>F", function()
  require("conform").format()
end, { desc = "Format current buffer" })
-- 空格 f d：用 Telescope 搜索诊断。
vim.keymap.set("n", "<leader>fd", function()
  require("telescope.builtin").diagnostics()
end, { desc = "Search diagnostics" })
-- [d：跳到上一条诊断，并打开说明浮窗。
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
-- ]d：跳到下一条诊断，并打开说明浮窗。
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

-- 初始化外部工具管理器，可用 :Mason 打开界面；此处不自动安装服务器。
require("mason").setup({})
-- 配置补全菜单；setup({}) 一般表示使用插件默认设置，这里覆盖部分默认项。
require("blink.cmp").setup({
  keymap = {
    -- 使用以 Enter 确认补全为核心的按键预设。
    preset = "enter",
    -- 清空 blink 对 Ctrl+Space 的预设操作。
    ["<C-Space>"] = {},
  },
  completion = {
    -- 默认选中候选项，但不把候选文字自动插进正文，等待用户确认。
    list = { selection = { preselect = true, auto_insert = false } },
    -- 选中候选后，延迟 300 毫秒自动显示说明文档。
    documentation = { auto_show = true, auto_show_delay_ms = 300 },
  },
  -- 补全来源依次包括语言服务、文件路径、代码片段、buffer 文本。
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  -- 优先使用预编译的 Rust 模糊匹配（按当前版本标签自动下载），不可用时回退到 Lua 并提示。
  fuzzy = { implementation = "prefer_rust_with_warning" },
  -- 启用函数签名/参数提示。
  signature = { enabled = true },
})
-- blink.cmp 在 Neovim 0.11+ 会自动把补全能力写入 vim.lsp.config("*")，各服务器无需再单独传入。

-- 在 nvim-lspconfig 的 Lua 默认配置上保留项目识别和 Neovim 专用设置。
-- 启动命令和文件类型使用上游默认值；注册配置与真正启用服务器是两个步骤。
vim.lsp.config("lua_ls", {
  -- 确定项目根目录，通过 on_dir(目录) 告诉 LSP 应在哪个项目启动。
  root_dir = function(bufnr, on_dir)
    -- 取得当前文件的完整路径并规范化。
    local file = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
    -- 取得 Neovim 配置目录，通常为 ~/.config/nvim。
    local config_dir = vim.fs.normalize(vim.fn.stdpath("config"))
    -- 编辑自己的 Neovim 配置时，把整个配置目录当成一个 Lua 项目。
    if vim.startswith(file, config_dir .. "/") then
      on_dir(config_dir)
    else
      -- 其他 Lua 文件向上寻找项目标记；找不到时退回文件所在目录。
      on_dir(vim.fs.root(bufnr, { ".luarc.json", ".luarc.jsonc", ".git" }) or vim.fs.dirname(file))
    end
  end,
  settings = {
    Lua = {
      -- 函数调用补全使用 Replace 模式处理调用片段。
      completion = { callSnippet = "Replace" },
      -- 关闭第三方库工作区检测提示。
      workspace = { checkThirdParty = false },
    },
  },
  -- 服务器初始化时，仅为 Neovim 自身配置项目补充专用 Lua 设置。
  on_init = function(client)
    if vim.fs.normalize(client.root_dir or "") == vim.fs.normalize(vim.fn.stdpath("config")) then
      -- Neovim 的 Lua 运行环境按 LuaJIT 分析。
      client.config.settings.Lua.runtime = { version = "LuaJIT" }
      -- 声明 vim 是合法全局变量，避免被报告为未定义。
      client.config.settings.Lua.diagnostics = { globals = { "vim" } }
      -- 把 Neovim 自带运行时加入分析库，供 API 识别和补全使用。
      client.config.settings.Lua.workspace.library = { vim.env.VIMRUNTIME }
      -- 把刚调整的设置通知给已初始化的服务器。
      client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    end
  end,
})
-- Mason 安装的 Vue 语言服务器目录；ts_ls 从这里加载 @vue/typescript-plugin。
local vue_language_server_path = vim.fn.stdpath("data")
  .. "/mason/packages/vue-language-server/node_modules/@vue/language-server"
-- 复用上游 TS 启动逻辑及附加命令，仅覆盖 Vue 支持和现有的项目识别规则。
vim.lsp.config("ts_ls", {
  -- javascriptreact 和 typescriptreact 分别是 JSX、TSX 的文件类型名；vue 交给 Vue 插件处理脚本部分。
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
  -- 加载 Vue 的 TypeScript 插件，让 .ts 文件能识别 import 进来的 .vue 组件。
  init_options = {
    plugins = {
      { name = "@vue/typescript-plugin", location = vue_language_server_path, languages = { "vue" } },
    },
  },
  -- 确定项目根目录，通过 on_dir(目录) 告诉 LSP 应在哪个项目启动。
  root_dir = function(bufnr, on_dir)
    -- 向上寻找 JS/TS 项目标记；找不到时不调用 on_dir，即不为该文件启动服务器。
    local root = vim.fs.root(bufnr, { "tsconfig.json", "jsconfig.json", "package.json", ".git" })
    if root then
      on_dir(root)
    end
  end,
})

-- Vue 完整复用上游默认配置，包括向 TS 转发请求和等待 TS 连接的重试逻辑。
-- Mason 已将 bin 加入 PATH；只有命令可用才启用，缺失时可通过 :Mason 安装后重启 Neovim。
-- Java 仍由 nvim-jdtls 单独启动，不在这里启用 jdtls，避免重复连接。
if vim.fn.executable("lua-language-server") == 1 then
  vim.lsp.enable("lua_ls")
end
-- Vue 依赖 TS；缺少 TS 时不单独启用 Vue，避免转发请求报错。
if vim.fn.executable("typescript-language-server") == 1 then
  vim.lsp.enable("ts_ls")
  if vim.fn.executable("vue-language-server") == 1 then
    vim.lsp.enable("vue_ls")
  end
end

-- 等语言服务真正连接到一个 buffer 后，再为这个 buffer 设置以下按键。
vim.api.nvim_create_autocmd("LspAttach", {
  -- 独立事件组；重新执行配置时清理旧回调，避免重复设置。
  group = vim.api.nvim_create_augroup("UserLspKeys", { clear = true }),
  callback = function(event)
    -- 局部辅助函数：统一创建普通模式映射，并把说明写入 desc。
    local function map(key, action, description)
      -- buffer = event.buf 把快捷键限制在此次连接到语言服务的文件内。
      vim.keymap.set("n", key, action, { buffer = event.buf, desc = description })
    end
    -- gd：查找/跳转到定义，结果由 Telescope 展示。
    map("gd", function()
      require("telescope.builtin").lsp_definitions()
    end, "Go to definition")
    -- gD：跳到声明（是否与定义不同，取决于语言和服务器）。
    map("gD", vim.lsp.buf.declaration, "Go to declaration")
    -- gy：跳到变量或表达式所对应的类型定义。
    map("gy", function()
      require("telescope.builtin").lsp_type_definitions()
    end, "Go to class/type")
    -- gri：查找实现（覆盖内置 gri 以使用 Telescope，原生 gi 保持不变）；jump_type = never 避免结果只有一项时直接跳走。
    map("gri", function()
      require("telescope.builtin").lsp_implementations({ jump_type = "never" })
    end, "Go to implementation")
    -- grr：查找符号在项目中的引用位置。
    map("grr", function()
      require("telescope.builtin").lsp_references()
    end, "Find references")
    -- Shift+k：查看光标下符号的悬浮文档。
    map("K", vim.lsp.buf.hover, "Documentation")
    -- 空格 r n：按语言服务理解的符号关系重命名。
    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    -- 空格 c a：显示代码操作，例如可用的快速修复。
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    -- 下面的整理导入快捷键仅为 Java 文件添加。
    if vim.bo[event.buf].filetype == "java" then
      -- 空格 i：通过 jdtls 整理 Java import。
      map("<leader>i", function()
        require("jdtls").organize_imports()
      end, "Java: organize imports")
    end
    -- 空格 o：搜索工作区符号；Java 默认隐藏 JDK 和第三方依赖中的类。
    map("<leader>o", function()
      local opts = {}
      if vim.bo[event.buf].filetype == "java" then
        -- jdtls 用 jdt:// URI 返回依赖/JDK 类，项目源码使用普通文件路径。
        opts.file_ignore_patterns =
          vim.list_extend(vim.deepcopy(require("telescope.config").values.file_ignore_patterns or {}), { "^jdt://" })
      end
      require("telescope.builtin").lsp_dynamic_workspace_symbols(opts)
    end, "Search project classes/symbols")
    -- 空格 Shift+o：搜索全部工作区符号，包括第三方依赖和 JDK 中的类。
    map("<leader>O", function()
      require("telescope.builtin").lsp_dynamic_workspace_symbols()
    end, "Search all classes/symbols (including dependencies)")
    -- 空格 d s：搜索当前文件中的符号。
    map("<leader>ds", function()
      require("telescope.builtin").lsp_document_symbols()
    end, "Search file symbols")
  end,
})

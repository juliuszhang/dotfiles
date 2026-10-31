-- 语言服务与补全配置。
-- LSP 让编辑器向语言服务器请求诊断、定义、重命名、格式化等能力。
-- Mason 安装服务器并加入 PATH；nvim-lspconfig 提供默认配置；vim.lsp 定制/启用；Neovim 原生补全展示候选。
-- 本文件配置 Lua、JavaScript/TypeScript、Vue；Java/Kotlin 由 config/java.lua 配置 IntelliJ LSP。
-- 快捷键 <leader> 是空格；大写 D/F/K 等需要 Shift，grr 是依次按 g、r、r。

-- 统一配置警告、错误等诊断信息的显示方式。
vim.diagnostic.config({
  -- 在行尾显示诊断文字，间隔 2 个空格；存在多个来源时显示来源名。
  virtual_text = { spacing = 2, source = "if_many" },
  -- 按严重程度排序诊断。
  severity_sort = true,
  -- 诊断浮窗使用圆角边框，并展示诊断来源。
  float = { border = "rounded", source = true },
})
-- 空格 Shift+d：浮窗查看当前行诊断。
vim.keymap.set("n", "<leader>D", function()
  vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Line diagnostics" })
-- 按文件类型选择格式化工具；其他类型回退到语言服务。Java/Kotlin 的快捷键直接调用 IntelliJ。
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
  if #vim.lsp.get_clients({ bufnr = 0, name = "intellij" }) > 0 then
    require("intellij-lsp.editor").format()
  else
    require("conform").format()
  end
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
-- 原生补全菜单：显示单项候选、模糊匹配和文档；不自动选中候选，确认前不插入候选文字。
vim.opt.completeopt = { "menu", "menuone", "popup", "fuzzy", "noinsert", "noselect" }
-- Java/Kotlin 的补全由 IntelliJ 插件管理；其他服务器使用 Neovim 内置补全。
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserNativeCompletion", { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name == "intellij" then
      return
    end
    if client:supports_method("textDocument/completion") then
      -- Neovim 支持扩展触发字符；输入标识符时也自动请求补全，保留服务器自己的触发符。
      -- 动态注册补全的服务器没有静态 completionProvider，此时跳过扩展，只启用补全。
      local provider = client.server_capabilities.completionProvider
      if provider then
        local triggers = provider.triggerCharacters or {}
        for char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):gmatch(".") do
          if not vim.tbl_contains(triggers, char) then
            triggers[#triggers + 1] = char
          end
        end
        provider.triggerCharacters = triggers
      end
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
    end
    -- 其他语言按 Neovim 默认的插入模式 Ctrl+s 查看参数提示。
  end,
})

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
      -- Neovim 的 Lua 运行环境按 LuaJIT 分析；require 按 Neovim 的 lua/ 目录规则严格解析，
      -- 避免 require("telescope") 被同名文件（如主题的 integrations/telescope.lua）误匹配。
      client.config.settings.Lua.runtime = {
        version = "LuaJIT",
        path = { "?.lua", "?/init.lua", "lua/?.lua", "lua/?/init.lua" },
        pathStrict = true,
      }
      -- 声明 vim 是合法全局变量，避免被报告为未定义。
      client.config.settings.Lua.diagnostics = { globals = { "vim" } }
      -- 把 Neovim 自带运行时、libuv（vim.uv）类型和已加载插件的 lua 目录加入分析库，
      -- 使 require("telescope") 等插件 API 也有补全、跳转和类型检查。
      local library = { vim.env.VIMRUNTIME, "${3rd}/luv/library" }
      for _, plugin in ipairs(vim.pack.get()) do
        if plugin.active and vim.uv.fs_stat(plugin.path .. "/lua") then
          library[#library + 1] = plugin.path .. "/lua"
        end
      end
      client.config.settings.Lua.workspace.library = library
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
-- Java/Kotlin 由 IntelliJ LSP 管理，不在这里启用其他 Java 服务。
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
    -- grr：统一使用 Telescope 查找引用，包括 Java/Kotlin。
    map("grr", function()
      require("telescope.builtin").lsp_references()
    end, "Find references")
    -- K 悬浮文档由 Neovim 在服务支持 hover 时自动映射。
    -- 空格 r n：按语言服务理解的符号关系重命名。
    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    -- 空格 c a：显示代码操作，例如可用的快速修复。
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    -- 下面的整理导入快捷键仅为 Java 文件添加。
    if vim.bo[event.buf].filetype == "java" then
      -- 空格 i：通过标准 LSP 代码操作整理 Java import。
      map("<leader>i", function()
        vim.lsp.buf.code_action({
          context = { only = { "source.organizeImports" }, diagnostics = {} },
          apply = true,
        })
      end, "Java: organize imports")
    end
    -- 空格 o：搜索工作区符号；Java 默认隐藏 JDK 和第三方依赖中的类。
    map("<leader>o", function()
      local opts = {}
      if vim.bo[event.buf].filetype == "java" then
        -- IntelliJ 用 jar:/jrt: URI 返回依赖/JDK 类；jar: 可能被转换成带目录的 buffer 名。
        opts.file_ignore_patterns = vim.list_extend(
          vim.deepcopy(require("telescope.config").values.file_ignore_patterns or {}),
          { "jar:", "jrt:" }
        )
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

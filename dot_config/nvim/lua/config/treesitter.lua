-- Tree-sitter 语法高亮：按语言的语法树识别代码结构。
-- 解析器负责理解语法，highlights 查询负责指定哪些结构使用哪些高亮。
-- 启动时只注册规则；解析器安装由 :TSInstallConfigured 手动触发。

-- 文件类型确定时，尝试为下面列出的文件类型启用 Tree-sitter。
vim.api.nvim_create_autocmd("FileType", {
  -- 独立事件组；重新执行配置时替换旧规则。
  group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
  -- 这里填写 Neovim 文件类型名，可能与解析器语言名不同，例如 typescriptreact 对应 tsx。
  pattern = {
    "java",
    "lua",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "mermaid",
    "markdown",
  },
  callback = function(event)
    -- 把当前 buffer 的文件类型映射为 Tree-sitter 语言名。
    local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
    -- pcall 会捕获报错：query_ok 表示调用成功，query 是找到的 highlights 查询。
    local query_ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
    -- 只有查询存在才尝试启动高亮；解析器缺失等错误会被 pcall 捕获，不中断配置。
    local started = query_ok and query and pcall(vim.treesitter.start, event.buf, lang)
    -- Keep Vim syntax for Mermaid forms the parser does not cover (e.g. graph TD).
    -- Mermaid 即使成功启用 Tree-sitter，也保留传统语法高亮来补充未覆盖的语法。
    if started and lang == "mermaid" then
      vim.bo[event.buf].syntax = "mermaid"
    end
    if started then
      -- 有 indents 查询的语言按语法树缩进，替代传统的正则缩进规则。
      local indent_ok, indents = pcall(vim.treesitter.query.get, lang, "indents")
      if indent_ok and indents then
        vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
      -- 按语法树折叠（zM 全部折叠、za 切换当前、zR 全部展开）；只设置正在显示此 buffer 的窗口。
      -- diff 窗口保留按变更块折叠（foldmethod=diff）。
      for _, win in ipairs(vim.fn.win_findbuf(event.buf)) do
        if not vim.wo[win].diff then
          vim.wo[win][0].foldmethod = "expr"
          vim.wo[win][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        end
      end
    end
    -- 缺少查询或启动失败时，停止 Tree-sitter，并回退到该文件类型的传统语法高亮。
    if not started then
      pcall(vim.treesitter.stop, event.buf)
      vim.bo[event.buf].syntax = vim.bo[event.buf].filetype
    end
  end,
})

-- Explicit installation keeps network/build work out of normal startup.
-- 定义手动命令 :TSInstallConfigured，把下载/编译工作与日常启动分开。
vim.api.nvim_create_user_command("TSInstallConfigured", function()
  -- 这里填写解析器名；tsx 用于 TSX，markdown_inline 处理 Markdown 内联语法。
  require("nvim-treesitter").install({
    "java",
    "lua",
    "javascript",
    "typescript",
    "tsx",
    "json",
    "mermaid",
    "markdown",
    "markdown_inline",
    "vim",
    "regex",
    "bash",
  })
end, { desc = "Install parsers used by this configuration" })

-- 折叠按窗口选择来源：IntelliJ 已连接时使用服务范围，否则保留 Tree-sitter。
-- 上游 on_attach 只设置当时的当前窗口；切换文件/分屏，以及后台连接时需同步其余窗口。
-- diff 窗口不参与，保留按变更块折叠。
local function refresh_window_folds()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "" and not vim.wo[win].diff then
      local clients = vim.lsp.get_clients({ bufnr = buf, name = "intellij", method = "textDocument/foldingRange" })
      if #clients > 0 then
        if vim.wo[win].foldexpr ~= "v:lua.vim.lsp.foldexpr()" then
          vim.api.nvim_win_call(win, function()
            require("intellij-lsp.client").setup_folding(require("intellij-lsp").config)
          end)
        end
      elseif vim.treesitter.highlighter.active[buf] then
        -- 清除插件留在窗口中的 foldtext，避免切回其他语言时继续调用 LSP。
        vim.wo[win].foldmethod = "expr"
        vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo[win].foldtext = vim.api.nvim_get_option_info2("foldtext", {}).default
      elseif vim.wo[win].foldexpr == "v:lua.vim.lsp.foldexpr()" then
        -- 没有解析器的普通文本也不能继承上一个 Java 文件的 LSP 折叠。
        for _, option in ipairs({ "foldmethod", "foldexpr", "foldtext" }) do
          vim.wo[win][option] = vim.api.nvim_get_option_info2(option, {}).default
        end
      end
    end
  end
end
vim.api.nvim_create_autocmd({ "BufWinEnter", "LspAttach", "LspDetach" }, {
  group = vim.api.nvim_create_augroup("UserWindowFolds", { clear = true }),
  callback = function()
    -- 等插件 on_attach 完成，或客户端真正断开后再校正窗口选项。
    vim.schedule(refresh_window_folds)
  end,
})

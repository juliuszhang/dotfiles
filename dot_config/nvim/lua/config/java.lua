-- IntelliJ LSP 在启动时配置，提前识别 Maven/Gradle 项目；不使用 Java FileType 懒加载。
-- 服务使用下载包内的 JBR；default_sdk 仅供未指定 JDK 的项目分析使用。
local M = {}
local configured = false

function M.setup()
  if configured then
    return
  end
  configured = true

  local default_sdk
  for _, home in ipairs({
    vim.env.JAVA_HOME or "",
    "/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home",
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home",
  }) do
    if home ~= "" and vim.fn.executable(home .. "/bin/java") == 1 then
      default_sdk = home
      break
    end
  end

  require("intellij-lsp").setup({
    default_sdk = default_sdk,
    -- 不预先接受服务器协议；首次交互启动由用户确认协议、地区及数据共享选项。
    -- 补全、参数提示、LSP 折叠和文件模板使用插件原生默认能力。
    -- 保留现有 Leader 布局，避免 <leader>ws 与关闭文件的 <leader>w 冲突。
    keymaps = false,
    -- grr 统一使用 Telescope，避免插件在 on_attach 中覆盖自定义映射。
    references = false,
    -- 统一的回车映射同时支持原生补全和括号内换行，见 config/editing.lua。
    enter_accepts_completion = false,
    -- 保留主题和手动格式化习惯；Java/Kotlin 的 <leader>F 直接调用插件格式化。
    colorscheme = false,
    single_key_select = false,
    -- run=false 同时禁用依赖它的调试功能；当前没有 nvim-dap。Git 继续使用 Fugitive。
    run = false,
    git = false,
  })
end

return M

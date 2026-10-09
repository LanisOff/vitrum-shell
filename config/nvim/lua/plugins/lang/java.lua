return {
  "mfussenegger/nvim-jdtls",
  ft = "java",
  config = function()
    local grp = vim.api.nvim_create_augroup("UserJdtls", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = grp,
      pattern = "java",
      callback = function()
        -- Arch keeps JDKs under /usr/lib/jvm and only one is on PATH at a
        -- time (archlinux-java). If `java` is already there, leave it alone;
        -- otherwise put the newest JDK we can find in front, so jdtls can
        -- start without the user having run archlinux-java set.
        if vim.fn.executable("java") ~= 1 then
          local candidates = vim.fn.glob("/usr/lib/jvm/java-*-openjdk/bin", true, true)
          table.sort(candidates, function(a, b) return a > b end)  -- newest first
          for _, jdk in ipairs(candidates) do
            if vim.fn.isdirectory(jdk) == 1 then
              vim.env.PATH = jdk .. ":" .. (vim.env.PATH or "")
              break
            end
          end
        end

        local jdtls = require("jdtls")
        local data = vim.fn.stdpath("data")
        local mason = data .. "/mason/packages"
        local jdtls_bin = vim.fn.exepath("jdtls")
        if jdtls_bin == "" then jdtls_bin = data .. "/mason/bin/jdtls" end

        local root = vim.fs.root(0, { "gradlew", "mvnw", ".git", "pom.xml", "build.gradle" }) or vim.fn.getcwd()
        local name = vim.fn.fnamemodify(root, ":p:h:t")
        local workspace = data .. "/jdtls-workspace/" .. name

        local caps = vim.lsp.protocol.make_client_capabilities()
        local ok, blink = pcall(require, "blink.cmp")
        if ok then caps = blink.get_lsp_capabilities(caps) end

        -- DAP + test bundles
        local bundles = {}
        vim.list_extend(bundles, vim.split(vim.fn.glob(mason .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar", true), "\n"))
        vim.list_extend(bundles, vim.split(vim.fn.glob(mason .. "/java-test/extension/server/*.jar", true), "\n"))

        jdtls.start_or_attach({
          cmd = { jdtls_bin, "-data", workspace },
          root_dir = root,
          capabilities = caps,
          init_options = { bundles = bundles },
          settings = { java = { signatureHelp = { enabled = true }, contentProvider = { preferred = "fernflower" } } },
          on_attach = function()
            require("jdtls").setup_dap({ hotcodereplace = "auto" })
          end,
        })
      end,
    })
  end,
}

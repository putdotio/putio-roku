import { configDefaults, defineConfig } from "vitest/config";

// Vitest ignores .gitignore, so harness worktrees inside the checkout need an explicit exclude.
export default defineConfig({
  test: {
    exclude: [...configDefaults.exclude, ".claude/worktrees/**"],
  },
});

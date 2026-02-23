-- Test: resolve_path_at_revision follows renames and copies
-- Validates that git.resolve_path_at_revision correctly detects old file paths

local git = require("codediff.core.git")

-- Helper: create a temp git repo with rename history
local function create_rename_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local function run(cmd)
    return vim.fn.system("cd " .. vim.fn.shellescape(dir) .. " && git " .. cmd)
  end
  run("init")
  run("config user.email 'test@test.com'")
  run("config user.name 'test'")
  return dir, run
end

describe("resolve_path_at_revision", function()
  it("Returns old path for a renamed file", function()
    local dir, run = create_rename_repo()

    -- Create file, commit, rename, commit
    vim.fn.writefile({ "content" }, dir .. "/old.lua")
    run("add .")
    run("commit -m 'initial'")
    local initial = vim.trim(run("rev-parse HEAD"))

    run("mv old.lua new.lua")
    run("commit -m 'rename'")

    local done = false
    local resolved = nil

    git.resolve_path_at_revision(initial, dir, "new.lua", function(err, path)
      assert.is_nil(err)
      resolved = path
      done = true
    end)

    vim.wait(5000, function() return done end)
    assert.is_true(done, "Callback should complete")
    assert.equal("old.lua", resolved, "Should resolve to old path before rename")

    vim.fn.delete(dir, "rf")
  end)

  it("Returns same path for a file without renames", function()
    local dir, run = create_rename_repo()

    vim.fn.writefile({ "content" }, dir .. "/stable.lua")
    run("add .")
    run("commit -m 'initial'")
    local initial = vim.trim(run("rev-parse HEAD"))

    -- Make another commit (no rename)
    vim.fn.writefile({ "modified" }, dir .. "/stable.lua")
    run("add .")
    run("commit -m 'modify'")

    local done = false
    local resolved = nil

    git.resolve_path_at_revision(initial, dir, "stable.lua", function(err, path)
      assert.is_nil(err)
      resolved = path
      done = true
    end)

    vim.wait(5000, function() return done end)
    assert.is_true(done, "Callback should complete")
    assert.equal("stable.lua", resolved, "Should return same path when no rename")

    vim.fn.delete(dir, "rf")
  end)

  it("Follows multi-step renames", function()
    local dir, run = create_rename_repo()

    vim.fn.writefile({ "content" }, dir .. "/a.lua")
    run("add .")
    run("commit -m 'initial'")
    local initial = vim.trim(run("rev-parse HEAD"))

    run("mv a.lua b.lua")
    run("commit -m 'rename a to b'")
    run("mv b.lua c.lua")
    run("commit -m 'rename b to c'")

    local done = false
    local resolved = nil

    git.resolve_path_at_revision(initial, dir, "c.lua", function(err, path)
      assert.is_nil(err)
      resolved = path
      done = true
    end)

    vim.wait(5000, function() return done end)
    assert.is_true(done, "Callback should complete")
    assert.equal("a.lua", resolved, "Should resolve through chain of renames to original path")

    vim.fn.delete(dir, "rf")
  end)

  it("Follows directory renames", function()
    local dir, run = create_rename_repo()

    vim.fn.mkdir(dir .. "/old_dir", "p")
    vim.fn.writefile({ "content" }, dir .. "/old_dir/file.lua")
    run("add .")
    run("commit -m 'initial'")
    local initial = vim.trim(run("rev-parse HEAD"))

    run("mv old_dir new_dir")
    run("commit -m 'rename dir'")

    local done = false
    local resolved = nil

    git.resolve_path_at_revision(initial, dir, "new_dir/file.lua", function(err, path)
      assert.is_nil(err)
      resolved = path
      done = true
    end)

    vim.wait(5000, function() return done end)
    assert.is_true(done, "Callback should complete")
    assert.equal("old_dir/file.lua", resolved, "Should resolve through directory rename")

    vim.fn.delete(dir, "rf")
  end)
end)

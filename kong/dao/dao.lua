local inspect = require "inspect"

local Object = require "classic"
local Errors = require "kong.dao.errors"
local schemas_validation = require "kong.dao.schemas_validation"

local function check_arg(arg, arg_n, exp_type)
  if type(arg) ~= exp_type then
    local info = debug.getinfo(2)
    local err = string.format("bad argument #%d to '%s' (%s expected, got %s)",
                              arg_n, info.name, exp_type, type(arg))
    error(err, 3)
  end
end

local function check_not_empty(tbl, arg_n)
  if next(tbl) == nil then
    local info = debug.getinfo(2)
    local err = string.format("bad argument #%d to '%s' (expected table to not be empty)",
                              arg_n, info.name)
    error(err, 3)
  end
end

--- DAO
-- this just avoids having to deal with instanciating models

local DAO = Object:extend()

function DAO:new(db, model_mt, schema, constraints)
  self.db = db
  self.model_mt = model_mt
  self.schema = schema
  self.table = schema.table
  self.constraints = constraints
end

function DAO:insert(tbl)
  check_arg(tbl, 1, "table")

  local model = self.model_mt(tbl)
  local ok, err = model:validate {dao = self}
  if not ok then
    return nil, err
  end

  for col, field in pairs(model.__schema.fields) do
    if field.dao_insert_value and model[col] == nil then
      local f = self.db.dao_insert_values[field.type]
      if f then
        model[col] = f()
      end
    end
  end

  return self.db:insert(self.table, self.schema, model, self.constraints)
end

function DAO:find(tbl)
  check_arg(tbl, 1, "table")

  local model = self.model_mt(tbl)
  if not model:has_primary_keys() then
    error("Missing PRIMARY KEY field", 2)
  end

  local primary_keys, _, _, err = model:extract_keys()
  if err then
    return nil, Errors.schema(err)
  end

  return self.db:find(self.table, self.schema, primary_keys)
end

function DAO:find_all(tbl, page_offset, page_size)
  if tbl ~= nil then
    check_arg(tbl, 1, "table")
    check_not_empty(tbl, 1)
    local ok, err = schemas_validation.is_schema_subset(tbl, self.schema)
    if not ok then
      return nil, Errors.schema(err)
    end
  end

  return self.db:find_all(self.table, tbl, self.schema)
end

function DAO:find_page(tbl, page_offset, page_size)
   if tbl ~= nil then
    check_arg(tbl, 1, "table")
    check_not_empty(tbl, 1)
    local ok, err = schemas_validation.is_schema_subset(tbl, self.schema)
    if not ok then
      return nil, Errors.schema(err)
    end
  end

  if page_size == nil then
    page_size = 100
  end

  check_arg(page_size, 3, "number")

  return self.db:find_page(self.table, tbl, page_offset, page_size, self.schema)
end

function DAO:count(tbl)
  if tbl ~= nil then
    check_arg(tbl, 1, "table")
    check_not_empty(tbl, 1)
    local ok, err = schemas_validation.is_schema_subset(tbl, self.schema)
    if not ok then
      return nil, Errors.schema(err)
    end
  end

  if tbl ~= nil and next(tbl) == nil then
    tbl = nil
  end

  return self.db:count(self.table, tbl, self.schema)
end

local function fix(old, new, schema)
  for col, field in pairs(schema.fields) do
    if old[col] ~= nil and new[col] ~= nil and field.schema ~= nil then
      local f_schema, err = type(field.schema) == "function" and field.schema(old) or field.schema
      if err then
        error(err)
      end
      for f_k in pairs(f_schema.fields) do
        if new[col][f_k] == nil and old[col][f_k] ~= nil then
          new[col][f_k] = old[col][f_k]
        end
      end

      fix(old[col], new[col], f_schema)
    end
  end
end

function DAO:update(tbl, filter_keys)
  check_arg(tbl, 1, "table")
  check_not_empty(tbl, 1)

  local full_update = false
  if type(filter_keys) ~= "boolean" then
    check_arg(filter_keys, 2, "table")
    check_not_empty(filter_keys, 2)
    for k, v in pairs(filter_keys) do
      if tbl[k] == nil then
        tbl[k] = v
      end
    end
  else
    full_update = filter_keys
  end

  local model = self.model_mt(tbl)
  local ok, err = model:validate {dao = self, update = true, full_update = full_update}
  if not ok then
    return nil, err
  end

  local primary_keys, values, nils, err = model:extract_keys()
  if err then
    return nil, Errors.schema(err)
  end

  local old, err = self.db:find(self.table, self.schema, primary_keys)
  if err then
    return nil, err
  elseif old == nil then
    return
  end

  if not full_update then
    fix(old, values, self.schema)
  end

  local res, err = self.db:update(self.table, self.schema, self.constraints, primary_keys, values, nils, full_update)
  if err then
    return nil, err
  elseif res then
    return setmetatable(res, nil)
  end
end

function DAO:delete(tbl)
  check_arg(tbl, 1, "table")

  local model = self.model_mt(tbl)
  if not model:has_primary_keys() then
    error("Missing PRIMARY KEY field", 2)
  end

  local primary_keys, values, nils, err = model:extract_keys()
  if err then
    return nil, Errors.schema(err)
  end

  return self.db:delete(self.table, self.schema, primary_keys, self.constraints)
end

return DAO

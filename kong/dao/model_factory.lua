local Errors = require "kong.dao.errors"
local schemas_validation = require "kong.dao.schemas_validation"
local validate = schemas_validation.validate_entity

return setmetatable({}, {
  __call = function(_, schema)
    local Model_mt = {}
    Model_mt.__meta = {
      __schema = schema,
      __name = schema.name,
      __table = schema.table
    }

    function Model_mt.__index(self, key)
      if key and string.find(key, "__") == 1 then
        local meta_field = Model_mt.__meta[key]
        if meta_field then
          return meta_field
        end
      end

      return Model_mt[key]
    end

    function Model_mt:validate(opts)
      local ok, errors, self_check_err = validate(self, self.__schema, opts)
      if errors ~= nil then
        return nil, Errors.schema(errors)
      elseif self_check_err ~= nil then
        -- TODO: merge errors and self_check_err now that our errors handle this
        return nil, Errors.schema(self_check_err)
      end
      return ok
    end

    function Model_mt:extract_keys()
      local schema = self.__schema
      local primary_keys, values, nils = {}, {}, {}
      for _, key in pairs(schema.primary_key) do
        primary_keys[key] = self[key]
      end
      for col in pairs(schema.fields) do
        if primary_keys[col] == nil then
          if self[col] ~= nil then
            values[col] = self[col]
          else
            nils[col] = true
          end
        end
      end
      return primary_keys, values, nils
    end

    return setmetatable({}, {
      __call = function(_, tbl)
        local m = {}
        for k,v in pairs(tbl) do
          m[k] = v
        end
        return setmetatable(m, Model_mt)
      end
    })
  end
})

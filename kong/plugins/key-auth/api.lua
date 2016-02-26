local crud = require "kong.api.crud_helpers"

local global_route = {
  before = function(self, dao_factory, helpers)
    crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
    self.params.consumer_id = self.consumer.id
  end,

  GET = function(self, dao_factory)
    crud.paginated_set(self, dao_factory.keyauth_credentials)
  end,

  PUT = function(self, dao_factory)
    crud.put(self.params, dao_factory.keyauth_credentials)
  end,

  POST = function(self, dao_factory)
    crud.post(self.params, dao_factory.keyauth_credentials)
  end
}

local single_route = {
  before = function(self, dao_factory, helpers)
    crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
    self.params.consumer_id = self.consumer.id

    local err
    self.keyauth_credential, err = dao_factory.keyauth_credentials:find(self.params)
    if err then
      return helpers.yield_error(err)
    elseif self.keyauth_credential == nil then
      return helpers.responses.send_HTTP_NOT_FOUND()
    end
  end,

  GET = function(self, dao_factory, helpers)
    return helpers.responses.send_HTTP_OK(self.keyauth_credential)
  end,

  PATCH = function(self, dao_factory)
    crud.patch(self.params, dao_factory.keyauth_credentials, self.keyauth_credential)
  end,

  DELETE = function(self, dao_factory)
    crud.delete(self.keyauth_credential, dao_factory.keyauth_credentials)
  end
}

return {
  ["/consumers/:username_or_id/key-auth/"] = global_route,
  ["/consumers/:username_or_id/key-auth/:id"] = single_route,
  -- Deprecated in 0.5.0, maintained for backwards compatibility.
  ["/consumers/:username_or_id/keyauth/"] = global_route,
  ["/consumers/:username_or_id/keyauth/:id"] = single_route
}

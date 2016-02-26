local crud = require "kong.api.crud_helpers"

local global_route = {
  before = function(self, dao_factory, helpers)
    crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
    self.params.consumer_id = self.consumer.id
  end,

  GET = function(self, dao_factory)
    crud.paginated_set(self, dao_factory.basicauth_credentials)
  end,

  PUT = function(self, dao_factory)
    crud.put(self.params, dao_factory.basicauth_credentials)
  end,

  POST = function(self, dao_factory)
    crud.post(self.params, dao_factory.basicauth_credentials)
  end
}

local single_route = {
  before = function(self, dao_factory, helpers)
    crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
    self.params.consumer_id = self.consumer.id
    self.basicauth_credential, err = dao_factory.basicauth_credentials:find(self.params)
    if err then
      return helpers.yield_error(err)
    elseif self.basicauth_credential == nil then
      return helpers.responses.send_HTTP_NOT_FOUND()
    end
  end,

  GET = function(self, dao_factory, helpers)
    return helpers.responses.send_HTTP_OK(self.basicauth_credential)
  end,

  PATCH = function(self, dao_factory)
    crud.patch(self.params, dao_factory.basicauth_credentials, self.basicauth_credential)
  end,

  DELETE = function(self, dao_factory)
    crud.delete(self.basicauth_credential, dao_factory.basicauth_credentials)
  end
}

return {
  ["/consumers/:username_or_id/basic-auth/"] = global_route,
  ["/consumers/:username_or_id/basic-auth/:id"] = single_route,
  -- Deprecated in 0.5.0, maintained for backwards compatibility.
  ["/consumers/:username_or_id/basicauth/"] = global_route,
  ["/consumers/:username_or_id/basicauth/:id"] = single_route
}

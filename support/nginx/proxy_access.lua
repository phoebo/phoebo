local regex = [=[(([0-9a-f]{8})\.)?([^\.]+)\.[^\.]+\.[^\.]+$]=]
local m = ngx.re.match(ngx.var.http_host, regex)
if m and string.sub(ngx.var.http_host, 0 - string.len(ngx.var.server_name) - 1) == ("." .. ngx.var.server_name) then
    local service, ref = m[3], m[1]

    local phoebo_token = ngx.var.cookie_phoebo_token;
    local token_regex = "^[0-9a-f]{32}$"

    -- Check token format
    if phoebo_token and not ngx.re.match(phoebo_token, token_regex) then
        phoebo_token = nil
    end

    -- Connect to Redis
    local cjson = require "cjson"
    local redis = require "resty.redis"
    local red = redis:new()

    red:set_timeout(1000) -- 1 second

    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect to redis: ", err)
        return ngx.exit(500)
    end

    -- Check token itself
    if phoebo_token then
        local key = "proxy/tokens/" .. phoebo_token
        local token_value, err = red:get(key)
        if token_value and token_value ~= ngx.null then

            -- Update token expiration
            red:expire(key, 3600)

            local token_info = cjson.decode(token_value)
            if token_info[ngx.var.scheme] then
                ngx.var.target = token_info[ngx.var.scheme]
            else
                ngx.say(token_info["http"], " service not available")
                ngx.exit(503)
            end
        else
            phoebo_token = nil
        end
    end

    -- Create proxy access request if token is not valid
    -- and redirect to Phoebo CI for authorization
    if not phoebo_token then
        local resty_random = require "resty.random"
        local resty_str = require "resty.string"

        local request_data = cjson.encode({
            ["scheme"] = ngx.var.scheme,
            ["host"]   = ngx.var.http_host,
            ["port"]   = ngx.var.server_port,
            ["method"] = ngx.var.request_method,
            ["uri"]    = ngx.var.request_uri
        })

        -- Save request under unique random ID
        local i = 1
        local request_id

        repeat
            i = i + 1

            repeat
                strong_random = resty_random.bytes(16, true)
            until strong_random ~= nil

            request_id = resty_str.to_hex(strong_random)
            local key = "proxy/requests/" .. request_id

            local ans, err = red:set(key, request_data, "EX", 3600, "NX")
            if not ans then
                ngx.log(ngx.ERR, "error while saving request to redis: ", err)
                return ngx.exit(500)
            end

        until ans ~= ngx.null or i > 10

        if i > 10 then
            ngx.log(ngx.ERR, "error while generating random request key")
            return ngx.exit(500)
        end

        -- Save token into cookie until the browser is closed
        -- (we handle actual expiration by Redis)
        ngx.header["Set-Cookie"] = "phoebo_token=" .. request_id .. "; Path=/"

        ngx.redirect("http://" .. ngx.var.server_name .. "/proxy_access/" .. request_id)
    end
end
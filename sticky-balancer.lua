local balancer = require "ngx.balancer"
local cookie_name = "sticky_route"

-- Define backend server based on their capabilities (IP, port, weight, number of retries before timeout, duration of timeout, current number of fails, fail timestamp)
local servers = {
    { "backend_server_1", 8080, weight = 96, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0 },
    { "backend_server_2", 80, weight = 96, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0 },
    { "backend_server_3", 80, weight = 16, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0 },
}

-- Generate a weighted server list based on weights
local function generate_weighted_server_list(servers)
    local weighted_servers = {}
    for _, server in ipairs(servers) do
        for i = 1, server.weight do
            table.insert(weighted_servers, server)
        end
    end
    return weighted_servers
end

local weighted_servers = generate_weighted_server_list(servers)

-- Hash function to select server
local function hash(key, num_buckets)
    local hash = ngx.crc32_long(key)
    return (hash % num_buckets) + 1
end

-- Check if a server is available based on max_fails and fail_timeout
local function is_server_available(server)
    if server.fail_count >= server.max_fails then
        if (ngx.now() - server.last_fail_time) < server.fail_timeout then
            return false
        else
            server.fail_count = 0
            server.last_fail_time = 0
        end
    end
    return true
end

-- Select server based on cookie or assign a new one
local function select_server()
    local cookie = ngx.var["cookie_" .. cookie_name]
    local server_index

    if cookie then
        server_index = tonumber(cookie)
    else
        server_index = hash(ngx.var.remote_addr, #weighted_servers)
        ngx.header["Set-Cookie"] = cookie_name .. "=" .. server_index .. "; Path=/"
    end

    local server = weighted_servers[server_index]
    if is_server_available(server) then
        return server
    else
        -- If the selected server is not available, find another one
        for _, s in ipairs(weighted_servers) do
            if is_server_available(s) then
                return s
            end
        end
    end
    ngx.log(ngx.ERR, "No available servers")
    return nil
end

-- Main function to balance the request, adjust the no server block based on your needs
local function balancer_handler()
    local server = select_server()
    if not server then
        ngx.exit(502)
        return
    end
    local ok, err = balancer.set_current_peer(server[1], server[2])
    if not ok then
        ngx.log(ngx.ERR, "Failed to set the current peer: ", err)
        server.fail_count = server.fail_count + 1
        server.last_fail_time = ngx.now()
        return ngx.exit(500)
    end
end

return balancer_handler

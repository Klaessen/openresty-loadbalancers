local balancer = require "ngx.balancer"

-- Define your backend servers and their weights, max_fails, fail_timeout, and active_connections
local servers = {
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
    { "xxx", 80, weight = 35, max_fails = 3, fail_timeout = 30, fail_count = 0, last_fail_time = 0, active_connections = 0 },
}

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

-- Select the server with the least number of active connections
local function select_least_connections_server()
    local least_conn_server = nil
    for _, server in ipairs(servers) do
        if is_server_available(server) then
            if not least_conn_server or server.active_connections < least_conn_server.active_connections then
                least_conn_server = server
            end
        end
    end
    return least_conn_server
end

-- Main function to balance the request
local function balancer_handler()
    local server = select_least_connections_server()
    if not server then
        ngx.log(ngx.ERR, "No available servers")
        ngx.exit(502)
        return
    end

    server.active_connections = server.active_connections + 1

    local ok, err = balancer.set_current_peer(server[1], server[2])
    if not ok then
        ngx.log(ngx.ERR, "Failed to set the current peer: ", err)
        server.fail_count = server.fail_count + 1
        server.last_fail_time = ngx.now()
        return ngx.exit(500)
    end

    -- Decrement active connections when the request is done
    ngx.ctx.server = server
end

-- Hook to decrement active connections count after the request is processed
local function after_request()
    local server = ngx.ctx.server
    if server then
        server.active_connections = server.active_connections - 1
    end
end

ngx.timer.at(0, function()
    ngx.log(ngx.NOTICE, "Setting up the after request hook")
    ngx.on_abort(after_request)
end)

return balancer_handler

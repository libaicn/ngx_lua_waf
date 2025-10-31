local _M = {}

local china_ip_ranges = nil

function _M.ip2long(ip)
    if not ip or type(ip) ~= "string" then
        return nil
    end
    
    local parts = {}
    for part in string.gmatch(ip, "%d+") do
        table.insert(parts, tonumber(part))
    end
    
    if #parts ~= 4 then
        return nil
    end
    
    for _, part in ipairs(parts) do
        if part < 0 or part > 255 then
            return nil
        end
    end
    
    return parts[1] * 16777216 + parts[2] * 65536 + parts[3] * 256 + parts[4]
end

function _M.cidr_to_range(cidr)
    local ip, prefix = string.match(cidr, "([^/]+)/(%d+)")
    if not ip or not prefix then
        return nil, nil
    end
    
    prefix = tonumber(prefix)
    if prefix < 0 or prefix > 32 then
        return nil, nil
    end
    
    local ip_long = _M.ip2long(ip)
    if not ip_long then
        return nil, nil
    end
    
    local host_bits = 32 - prefix
    local network_mask = math.floor(4294967295 * (2^32 - 2^host_bits) / 2^32)
    local start_ip = math.floor(ip_long / (2^host_bits)) * (2^host_bits)
    local end_ip = start_ip + (2^host_bits) - 1
    
    return start_ip, end_ip
end

function _M.load_china_ip_ranges()
    if china_ip_ranges then
        return china_ip_ranges
    end
    
    local ok, ranges_module = pcall(require, 'wafconf.china_ip_ranges')
    if not ok or not ranges_module or not ranges_module.ranges then
        ngx.log(ngx.ERR, "Failed to load China IP ranges: ", ranges_module)
        return nil
    end
    
    local ranges = {}
    for _, cidr in ipairs(ranges_module.ranges) do
        local start_ip, end_ip = _M.cidr_to_range(cidr)
        if start_ip and end_ip then
            table.insert(ranges, {start_ip, end_ip})
        end
    end
    
    table.sort(ranges, function(a, b) return a[1] < b[1] end)
    
    china_ip_ranges = ranges
    return china_ip_ranges
end

function _M.binary_search_ip(ranges, ip_long)
    local left = 1
    local right = #ranges
    
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local range = ranges[mid]
        
        if ip_long < range[1] then
            right = mid - 1
        elseif ip_long > range[2] then
            left = mid + 1
        else
            return true
        end
    end
    
    return false
end

function _M.is_china_ip(ip)
    if not ip then
        return false
    end
    
    local ip_long = _M.ip2long(ip)
    if not ip_long then
        return false
    end
    
    local ranges = _M.load_china_ip_ranges()
    if not ranges or #ranges == 0 then
        return true
    end
    
    return _M.binary_search_ip(ranges, ip_long)
end

function _M.is_private_ip(ip)
    local ip_long = _M.ip2long(ip)
    if not ip_long then
        return false
    end
    
    if (ip_long >= 167772160 and ip_long <= 184549375) then
        return true
    end
    
    if (ip_long >= 2886729728 and ip_long <= 2887778303) then
        return true
    end
    
    if (ip_long >= 3232235520 and ip_long <= 3232301055) then
        return true
    end
    
    if (ip_long >= 2130706432 and ip_long <= 2147483647) then
        return true
    end
    
    return false
end

function _M.match_ip_in_list(ip, ip_list)
    if not ip_list or #ip_list == 0 then
        return false
    end
    
    local ip_long = _M.ip2long(ip)
    if not ip_long then
        return false
    end
    
    for _, ip_pattern in ipairs(ip_list) do
        if string.find(ip_pattern, "/") then
            local start_ip, end_ip = _M.cidr_to_range(ip_pattern)
            if start_ip and end_ip and ip_long >= start_ip and ip_long <= end_ip then
                return true
            end
        else
            if ip == ip_pattern then
                return true
            end
        end
    end
    
    return false
end

return _M

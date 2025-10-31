#!/usr/bin/env lua

local function test_ip2long()
    local function ip2long(ip)
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
    
    print("Testing IP to Long conversion:")
    print("127.0.0.1 -> " .. (ip2long("127.0.0.1") or "nil"))
    print("1.0.1.0 -> " .. (ip2long("1.0.1.0") or "nil"))
    print("223.255.255.255 -> " .. (ip2long("223.255.255.255") or "nil"))
    print("")
end

local function test_cidr()
    local function ip2long(ip)
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
        
        return parts[1] * 16777216 + parts[2] * 65536 + parts[3] * 256 + parts[4]
    end
    
    local function cidr_to_range(cidr)
        local ip, prefix = string.match(cidr, "([^/]+)/(%d+)")
        if not ip or not prefix then
            return nil, nil
        end
        
        prefix = tonumber(prefix)
        if prefix < 0 or prefix > 32 then
            return nil, nil
        end
        
        local ip_long = ip2long(ip)
        if not ip_long then
            return nil, nil
        end
        
        local host_bits = 32 - prefix
        local start_ip = math.floor(ip_long / (2^host_bits)) * (2^host_bits)
        local end_ip = start_ip + (2^host_bits) - 1
        
        return start_ip, end_ip
    end
    
    print("Testing CIDR to Range conversion:")
    local start, ending = cidr_to_range("192.168.0.0/16")
    if start and ending then
        print("192.168.0.0/16 -> " .. start .. " to " .. ending)
    end
    
    start, ending = cidr_to_range("1.0.1.0/24")
    if start and ending then
        print("1.0.1.0/24 -> " .. start .. " to " .. ending)
    end
    print("")
end

print("=== IP Geo Module Test ===")
print("")
test_ip2long()
test_cidr()
print("Tests completed!")

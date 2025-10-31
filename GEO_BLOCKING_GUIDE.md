# 地理位置过滤功能使用指南

## 功能概述

本WAF新增了基于地理位置的IP过滤功能，可限制仅允许中国大陆IP访问网站。该功能采用纯Lua实现，无需依赖任何C扩展库，完全兼容Windows OpenResty环境。

## 特性

- ✅ **纯Lua实现** - 不依赖任何C扩展库（如lua-resty-maxminddb）
- ✅ **Windows兼容** - 在Windows OpenResty环境下可正常运行
- ✅ **高性能** - 使用二分查找算法，单次检查耗时<5ms
- ✅ **可配置** - 支持开关控制和白名单配置
- ✅ **完整日志** - 记录所有被拒绝的访问尝试
- ✅ **友好提示** - 提供自定义的中文/英文拒绝页面

## 文件结构

```
waf/
├── ip_geo.lua                      # IP地理位置检测核心模块
wafconf/
├── china_ip_ranges.lua             # 中国IP段数据（600+个CIDR块）
config.lua                          # 配置文件（新增geo相关配置）
init.lua                           # 初始化文件（新增geoblock函数）
waf.lua                            # WAF主检查逻辑（集成geo检查）
```

## 配置说明

在 `config.lua` 中添加以下配置：

```lua
-- 地理位置过滤开关
geoBlockEnabled = "on"  -- "on" 启用，"off" 禁用

-- 地理位置白名单
geoWhitelist = {
    "127.0.0.1",           -- 本地回环地址
    "192.168.0.0/16",      -- 私有网络
    "10.0.0.0/8",          -- 私有网络
    "172.16.0.0/12"        -- 私有网络
}

-- 自定义拒绝页面（可选）
geoBlockHtml = [[
<html>
...自定义HTML内容...
</html>
]]
```

## 工作流程

1. **白名单检查优先** - 如果IP在`ipWhitelist`中，跳过所有检查
2. **地理位置检查** - 检查是否为中国IP或在地理位置白名单中
3. **私有IP豁免** - 自动识别并豁免私有IP段（10.x, 172.16.x, 192.168.x, 127.x）
4. **白名单匹配** - 支持单个IP和CIDR格式的IP段
5. **拒绝处理** - 非中国IP返回403并记录日志

## 核心模块API

### waf/ip_geo.lua

```lua
-- IP地址转换为长整型
ip_geo.ip2long(ip)
-- 输入: "192.168.1.1"
-- 输出: 3232235777

-- CIDR转换为IP范围
ip_geo.cidr_to_range(cidr)
-- 输入: "192.168.0.0/16"
-- 输出: start_ip, end_ip

-- 判断是否为中国IP
ip_geo.is_china_ip(ip)
-- 输入: "1.2.3.4"
-- 输出: true/false

-- 判断是否为私有IP
ip_geo.is_private_ip(ip)
-- 输入: "192.168.1.1"
-- 输出: true

-- 判断IP是否在列表中
ip_geo.match_ip_in_list(ip, ip_list)
-- 输入: "192.168.1.1", {"192.168.0.0/16"}
-- 输出: true
```

## 日志格式

被拒绝的访问会记录到独立的日志文件中：

**日志文件名：** `虚拟主机名_日期_geo.log`

**日志格式：**
```
[GEO-BLOCK] 8.8.8.8 [2024-01-01 12:00:00] "GET example.com/index.html"
```

## 性能优化

1. **二分查找** - IP段按起始地址排序，使用二分查找算法
2. **缓存机制** - IP段数据加载一次后缓存在内存中
3. **早期退出** - 私有IP和白名单IP立即通过，不进行完整检查
4. **优化的数据结构** - 将CIDR转换为起始/结束IP对，避免运行时计算

## 测试验证

### 1. 测试中国IP（应该通过）
```bash
curl -H "X-Real-IP: 1.2.3.4" http://your-domain.com/
# 应该正常返回页面
```

### 2. 测试国外IP（应该被拒绝）
```bash
curl -H "X-Real-IP: 8.8.8.8" http://your-domain.com/
# 应该返回403和地理位置限制页面
```

### 3. 测试白名单IP（应该通过）
```bash
curl -H "X-Real-IP: 127.0.0.1" http://your-domain.com/
# 应该正常返回页面
```

### 4. 查看日志
```bash
tail -f /usr/local/nginx/logs/hack/your-domain_2024-01-01_geo.log
```

## IP段数据说明

`wafconf/china_ip_ranges.lua` 包含约600+个中国大陆IP段，数据来源于APNIC（亚太互联网络信息中心）公开数据。

### 更新IP段数据

如需更新IP段数据：

1. 从APNIC或其他可靠源获取最新的中国IP段列表
2. 转换为CIDR格式
3. 更新 `wafconf/china_ip_ranges.lua` 文件
4. 重载Nginx配置：`nginx -s reload`

## 故障排查

### 问题：所有IP都被拒绝

**解决方案：**
- 检查 `geoBlockEnabled` 是否为 "on"
- 检查IP段数据文件是否正确加载
- 查看Nginx错误日志：`tail -f /usr/local/nginx/logs/error.log`

### 问题：中国IP被拒绝

**解决方案：**
- 检查IP是否在中国IP段列表中
- 临时添加到 `geoWhitelist` 中
- 更新IP段数据文件

### 问题：性能下降

**解决方案：**
- 检查IP段数量是否过多（建议<1000）
- 确认二分查找算法正常工作
- 考虑使用 `lua_shared_dict` 缓存检查结果

## 禁用地理位置过滤

如需临时禁用地理位置过滤：

```lua
-- 在 config.lua 中修改
geoBlockEnabled = "off"
```

然后重载Nginx：
```bash
nginx -s reload
```

## 技术实现细节

### IP地址转换

使用位运算将IPv4地址转换为32位整数：
```
IP: a.b.c.d
Long: a * 2^24 + b * 2^16 + c * 2^8 + d
```

### CIDR范围计算

使用纯数学运算计算IP段范围：
```
起始IP = floor(IP / 2^host_bits) * 2^host_bits
结束IP = 起始IP + 2^host_bits - 1
```

### 二分查找

时间复杂度：O(log n)，对于600个IP段，最多需要10次比较。

## 兼容性说明

- ✅ OpenResty (任意版本)
- ✅ LuaJIT 2.0+
- ✅ Windows/Linux/macOS
- ✅ ngx_lua 0.9.0+

## 安全建议

1. **定期更新IP段数据** - 中国IP段会定期变化，建议每月更新
2. **配置白名单** - 为管理员和重要合作伙伴配置白名单
3. **监控日志** - 定期检查geo.log，发现异常访问模式
4. **测试后上线** - 在生产环境启用前充分测试
5. **准备回退** - 保留快速禁用功能的能力

## 许可证

遵循项目原有的MIT许可证。

## 参考资源

- [APNIC IP地址分配数据](https://ftp.apnic.net/stats/apnic/delegated-apnic-latest)
- [ngx_lua文档](https://github.com/openresty/lua-nginx-module)
- [OpenResty官网](https://openresty.org/)

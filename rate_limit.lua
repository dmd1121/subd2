-- Проверка и обновление счетчиков
local function check_and_update_counters(user_id, config_key)
    local key = "rate_limit:user:" .. user_id
    local max_requests = tonumber(redis.call("HGET", config_key, "max_requests")) or 0
    local interval = tonumber(redis.call("HGET", config_key, "interval")) or 0

    local current = tonumber(redis.call("GET", key) or 0)
    if current >= max_requests then
        return 0  -- Лимит запросов исчерпан
    else
        redis.call("INCR", key)
        if current == 0 then
            redis.call("EXPIRE", key, interval)
        end
        return 1  -- Запрос разрешен
    end
end

-- KEYS[1] - ключ, по которому будем отслеживать запросы 
-- ARGV[1] - лимит запросов 
-- ARGV[2] - время окна в секундах 
local current = redis.call("GET", KEYS[1])
if current and tonumber(current) and tonumber(current) >= tonumber(ARGV[1]) then
    return 0
else
    current = redis.call("INCR", KEYS[1])
    if tonumber(current) == 1 then
        redis.call("EXPIRE", KEYS[1], ARGV[2])
    end
    return 1
end

-- Инициализация лимитера
local function initialize_rate_limiter(user_id, max_requests, interval)
    redis.call("SET", "rate_limit:user:" .. user_id, 0, "EX", interval)
    redis.call("HMSET", "rate_limit_config:user:" .. user_id, "max_requests", max_requests, "interval", interval)
end

-- Блокировка пользователя
local function block_user(user_id, block_duration)
    redis.call("SET", "block:user:" .. user_id, 1, "EX", block_duration)
end

-- Разблокировка пользователя
local function unblock_user(user_id)
    redis.call("DEL", "block:user:" .. user_id)
end

return {
    initialize_rate_limiter = initialize_rate_limiter,
    check_and_update_counters = check_and_update_counters,
    block_user = block_user,
    unblock_user = unblock_user
}

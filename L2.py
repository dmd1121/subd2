import redis

client = redis.StrictRedis(host='localhost', port=6379, db=0)

with open('rate_limit.lua', 'r', encoding='utf-8') as file:
    lua_script = file.read()

script_sha = client.script_load(lua_script)

def initialize_rate_limiter(user_id, max_requests, interval):
    client.evalsha(script_sha, 0, "initialize_rate_limiter", user_id, max_requests, interval)

def check_and_update_counters(user_id):
    config_key = "rate_limit_config:user:" + str(user_id)
    response = client.evalsha(script_sha, 0, "check_and_update_counters", user_id, config_key)
    if response == 0:
        # Бан на 5 минут
        block_user(user_id, 300)  
        print("Лимит запросов превышен. Доступ заблокирован.")
    elif response == 1:
        print("Запрос разрешен.")
    else:
        print("Произошла ошибка при выполнении Lua-скрипта.")

def block_user(user_id, block_duration):
    client.evalsha(script_sha, 0, "block_user", user_id, block_duration)

def unblock_user(user_id):
    client.evalsha(script_sha, 0, "unblock_user", user_id)

# Пользователь с ID 123, лимит 10 запросов за 60 секунд
initialize_rate_limiter(123, 10, 60)  

# Проверка и обновление счетчиков
check_and_update_counters(123)

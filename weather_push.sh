#!/bin/bash

# 从环境变量获取配置
APP_ID="$APP_ID"
APP_SECRET="$APP_SECRET"
OPEN_ID="$OPEN_ID"
TEMPLATE_ID="$TEMPLATE_ID"
CITY="淄博"  # 你想查询的城市

# 获取天气信息
get_weather() {
    local my_city="$1"
    local urls=(
        "http://www.weather.com.cn/textFC/hb.shtml"
        "http://www.weather.com.cn/textFC/db.shtml"
        "http://www.weather.com.cn/textFC/hd.shtml"
        "http://www.weather.com.cn/textFC/hz.shtml"
        "http://www.weather.com.cn/textFC/hn.shtml"
        "http://www.weather.com.cn/textFC/xb.shtml"
        "http://www.weather.com.cn/textFC/xn.shtml"
    )
    
    for url in "${urls[@]}"; do
        # 使用 curl 获取天气页面
        response=$(curl -s "$url")
        
        # 使用 grep 和 sed 提取天气数据
        weather_info=$(echo "$response" | grep -A 10 "conMidtab" | grep "$my_city" | sed -E 's/.*<td[^>]*>([^<]*)<\/td>.*/\1/g' | tr '\n' ' ')
        
        # 如果找到了天气信息，返回
        if [[ -n "$weather_info" ]]; then
            echo "$weather_info"
            return
        fi
    done
    
    echo "未找到该城市的天气信息"
}

# 获取 access token
get_access_token() {
    local url="https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${APP_ID}&secret=${APP_SECRET}"
    local response=$(curl -s "$url")
    local access_token=$(echo "$response" | jq -r '.access_token')
    
    echo "$access_token"
}

# 发送天气信息到微信公众号
send_weather() {
    local access_token="$1"
    local weather="$2"
    
    # 提取天气信息
    local temp=$(echo "$weather" | awk '{print $2 "——" $4 "摄氏度"}')
    local weather_type=$(echo "$weather" | awk '{print $5}')
    local wind_dir=$(echo "$weather" | awk '{print $6}')

    # 构建消息体
    local today=$(date +"%Y年%m月%d日")
    local body=$(jq -n \
        --arg touser "$OPEN_ID" \
        --arg template_id "$TEMPLATE_ID" \
        --arg today "$today" \
        --arg region "$CITY" \
        --arg weather "$weather_type" \
        --arg temp "$temp" \
        --arg wind_dir "$wind_dir" \
        '{
            touser: $touser,
            template_id: $template_id,
            url: "https://weixin.qq.com",
            data: {
                date: { value: $today },
                region: { value: $region },
                weather: { value: $weather },
                temp: { value: $temp },
                wind_dir: { value: $wind_dir }
            }
        }')
    
    # 发送请求
    local url="https://api.weixin.qq.com/cgi-bin/message/template/send?access_token=${access_token}"
    curl -s -X POST -H "Content-Type: application/json" -d "$body" "$url"
}

# 主程序
weather_report() {
    # 1. 获取 access_token
    local access_token=$(get_access_token)
    
    # 2. 获取天气
    local weather=$(get_weather "$CITY")
    echo "天气信息：$weather"
    
    # 3. 发送消息
    send_weather "$access_token" "$weather"
}

# 执行天气报告
weather_report

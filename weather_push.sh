#!/bin/bash

# 微信公众号配置
OPEN_ID="$OPEN_ID"          # 微信公众号 OpenID
TEMPLATE_ID="$TEMPLATE_ID"  # 微信模板 ID
CITY="淄博"                 # 你想查询的城市
WEATHER_API_URL="https://wttr.in/$CITY?format=%C+%t"

# 检查是否安装了 jq
if ! command -v jq &> /dev/null; then
    echo "jq 未安装，请安装 jq 工具。"
    exit 1
fi

# 获取天气信息
get_weather() {
    local response=$(curl -s "$WEATHER_API_URL")
    
    # 检查响应是否有效
    if [[ -z "$response" ]]; then
        echo "未找到该城市的天气信息"
        return
    fi

    echo "$response"
}

# 获取 access token
get_access_token() {
    local url="https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${APP_ID}&secret=${APP_SECRET}"
    local response=$(curl -s "$url")
    local access_token=$(echo "$response" | jq -r '.access_token')

    # 检查 access_token 是否有效
    if [[ "$access_token" == "null" ]]; then
        echo "获取 access_token 失败：$response"
        exit 1
    fi

    echo "$access_token"
}

# 发送天气信息到微信公众号
send_weather() {
    local access_token="$1"
    local weather="$2"
    
    # 提取天气信息
    local weather_type=$(echo "$weather" | awk '{print $1}')  # 天气状况
    local temp=$(echo "$weather" | awk '{print $2 "摄氏度"}')  # 温度

    # 构建消息体
    local today=$(date +"%Y年%m月%d日")
    local body=$(jq -n \
        --arg touser "$OPEN_ID" \
        --arg template_id "$TEMPLATE_ID" \
        --arg today "$today" \
        --arg region "$CITY" \
        --arg weather "$weather_type" \
        --arg temp "$temp" \
        '{
            touser: $touser,
            template_id: $template_id,
            url: "https://weixin.qq.com",
            data: {
                date: { value: $today },
                region: { value: $region },
                weather: { value: $weather },
                temp: { value: $temp }
            }
        }')

    # 发送请求
    local url="https://api.weixin.qq.com/cgi-bin/message/template/send?access_token=${access_token}"
    local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$body" "$url")
    
    # 检查发送是否成功
    local err_code=$(echo "$response" | jq -r '.errcode')
    if [[ "$err_code" != "0" ]]; then
        echo "发送消息失败：$response"
    else
        echo "天气信息发送成功！"
    fi
}

# 主程序
weather_report() {
    # 1. 获取 access_token
    local access_token=$(get_access_token)
    
    # 2. 获取天气
    local weather=$(get_weather)
    
    # 检查天气信息是否有效
    if [[ -z "$weather" ]]; then
        echo "未找到该城市的天气信息"
        exit 1
    fi

    echo "天气信息：$weather"
    
    # 3. 发送消息
    send_weather "$access_token" "$weather"
}

# 执行天气报告
weather_report

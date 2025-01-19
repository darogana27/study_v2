import json
import boto3
import datetime
import urllib.request
import math

# 定数をトップレベルで定義
API_URL = 'https://api.line.me/v2/bot/message/broadcast'  # Messaging APIのエンドポイント
TABLE_NAME = 'tg-daily-notify-electricity-table'
TOKEN_PARAM_NAME = '/tg-daily-notify/Line_Access_Token'  # チャネルアクセストークン用のパラメータ名を変更

# 料金プラン
BASIC_FEE = 885.72
RATE_1 = 29.90
RATE_2 = 35.41
RATE_3 = 37.48

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(TABLE_NAME)
    ssm = boto3.client('ssm')
    
    try:
        response = ssm.get_parameter(Name=TOKEN_PARAM_NAME, WithDecryption=True)
        CHANNEL_ACCESS_TOKEN = response['Parameter']['Value']
    except ssm.exceptions.ParameterNotFound:
        return {
            'statusCode': 500,
            'body': 'LINE Channel Access Token not found in Parameter Store'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }

    yesterday = datetime.datetime.now() - datetime.timedelta(days=1)
    date_key = yesterday.strftime("%Y%m%d")  # YYYYMMDD形式
    month = yesterday.strftime("%m")
    day = yesterday.strftime("%d")
    weekday_jp = ["日", "月", "火", "水", "木", "金", "土"][int(yesterday.strftime("%w"))]

    try:
        # DynamoDBからデータを取得
        response = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('YYYYMMDD').eq(date_key)
        )
        
        if not response['Items']:
            return {
                'statusCode': 404,
                'body': 'The specified item does not exist in the table'
            }

        item = response['Items'][0]
        daily_usage = item['ElectricityUsage']

        # 月の合計使用量を計算
        total_usage = calculate_monthly_usage(table, yesterday)

        # 累計請求金額を計算
        total_bill = calculate_total_bill(total_usage)

        # コメントを作成
        kWh_value = float(''.join(filter(str.isdigit, daily_usage))) / 10
        if kWh_value <= 5:
            comment = "この調子です！\nこのまま節電を意識しましょう！"
        elif kWh_value <= 15:
            comment = "使いすぎではないですが\n節約を意識しましょう！"
        else:
            comment = "使いすぎじゃい！\n気を付けぃ！"

        # メッセージを作成
        message = (
            f"{month}/{day}({weekday_jp})の電気使用量は\n{daily_usage}です\n\n"
            f"{comment}\n\n"
            f"現時点での翌月請求予定\n使用量\n{total_usage} kWh\n"
            f"金額\n{total_bill} 円"
        )
        
        # LINE Messaging APIで送信
        send_line_message(API_URL, CHANNEL_ACCESS_TOKEN, message)

        return {
            'statusCode': 200,
            'body': 'Message sent successfully'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }

def calculate_monthly_usage(table, yesterday):
    total_usage = 0
    
    # 請求月の開始日と終了日を計算
    billing_start = yesterday.replace(day=2)
    next_month = billing_start + datetime.timedelta(days=32)
    billing_end = next_month.replace(day=1)
    
    current_date = billing_start
    while current_date <= billing_end:
        date_key = current_date.strftime("%Y%m%d")
        
        try:
            response = table.query(
                KeyConditionExpression=boto3.dynamodb.conditions.Key('YYYYMMDD').eq(date_key)
            )
            
            if response['Items']:
                usage = float(''.join(filter(str.isdigit, response['Items'][0]['ElectricityUsage']))) / 10
                total_usage += usage
        except Exception as e:
            print(f"Error processing date {date_key}: {str(e)}")
            
        current_date += datetime.timedelta(days=1)

    return total_usage

def calculate_total_bill(total_usage):
    total_bill = BASIC_FEE
    
    if total_usage <= 120:
        total_bill += total_usage * RATE_1
    elif total_usage <= 300:
        total_bill += 120 * RATE_1 + (total_usage - 120) * RATE_2
    else:
        total_bill += 120 * RATE_1 + 180 * RATE_2 + (total_usage - 300) * RATE_3

    return math.floor(total_bill / 10) * 10

def send_line_message(api_url, channel_access_token, message):
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {channel_access_token}'
    }
    
    data = {
        'messages': [{
            'type': 'text',
            'text': message
        }]
    }
    
    req = urllib.request.Request(
        api_url,
        data=json.dumps(data).encode('utf-8'),
        headers=headers,
        method='POST'
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            response_body = response.read().decode('utf-8')
            if response.status != 200:
                raise RuntimeError(f'LINE API returned status code {response.status}: {response_body}')
    except urllib.error.URLError as e:
        raise RuntimeError(f'Failed to send LINE message: {str(e)}')
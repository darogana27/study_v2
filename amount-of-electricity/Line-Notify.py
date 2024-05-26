import json
import boto3
import datetime
import urllib.request

def lambda_handler(event, context):
    # S3クライアントを作成
    s3 = boto3.client('s3')
    
    # LINE Notify
    # アクセストークンは長いのでTOKENと定義します。APIに使うURLも同様です。
    TOKEN = '独自のトークン'
    api_url = 'https://notify-api.line.me/api/notify'
    
    BUCKET_NAME = 'tokyo-gas-electricity'

    # 前日の日付を取得
    yesterday = datetime.datetime.now() - datetime.timedelta(days=1)
    
    # 年と月と曜日を取得
    year = str(yesterday.year)
    month = str(yesterday.month).zfill(2)
    day = str(yesterday.day).zfill(2)
    
    # 曜日を取得して日本語の曜日名に変換
    weekday_num = yesterday.strftime("%w")
    weekdays_jp = ["日", "月", "火", "水", "木", "金", "土"]
    weekday_jp = weekdays_jp[int(weekday_num)]
    
    object_key = f'{year}/{month}/{day}.txt'

    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=object_key)
        file_content = response['Body'].read().decode('utf-8')
        
        # kWhの数値を取得
        kWh_value = float(''.join(filter(str.isdigit, file_content))) / 10  # 数字以外を取り除き、10で除算して kWh に変換
        # コメントを作成
        if kWh_value <= 5:
            comment = "この調子です！\nこのまま節電を意識しましょう！"
        elif kWh_value <= 15:
            comment = "使いすぎではないですが\n節約を意識しましょう！"
        else:
            comment = "使いすぎじゃい！\n気を付けぃ！"
        
        # 送信するメッセージ
        message = f"\n{month}/{day}({weekday_jp})の電気使用量は\n{file_content}です\n\n{comment}"
        
        # LINE Notifyに送信
        send_line_notify(api_url, TOKEN, message)  # api_url を引数として渡す
        
        return {
            'statusCode': 200,
            'body': 'Message sent successfully'
        }
    except Exception as e:
        return {
            'statusCode': 400,
            'body': str(e)
        }

def send_line_notify(api_url, token, message):  # api_url を引数に追加
    request_headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer' + ' ' + token
    }
    params = {'message': message}
    data = urllib.parse.urlencode(params).encode('ascii')
    req = urllib.request.Request(api_url, headers=request_headers, data=data, method='POST')
    conn = urllib.request.urlopen(req)

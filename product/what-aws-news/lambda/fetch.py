import json
import re
import boto3
import feedparser
import pytz
import time
from datetime import datetime, timedelta
from typing import List, Dict, Any
from botocore.exceptions import ClientError


# 定数定義
AWS_REGION = 'ap-northeast-1'
RSS_FEED_URL = 'https://aws.amazon.com/new/feed/'
JST_TIMEZONE = pytz.timezone('Asia/Tokyo')
UTC_TIMEZONE = pytz.UTC
DEFAULT_TTL_DAYS = 60

# AWS リソース初期化
def init_aws_resources():
    dynamodb = boto3.resource('dynamodb')
    sqs = boto3.client('sqs')
    ssm = boto3.client('ssm')
    
    table_name = ssm.get_parameter(Name='/what-aws-news/dynamodb/article/table-name', WithDecryption=True)['Parameter']['Value']
    queue_url = ssm.get_parameter(Name='/what-aws-news/sqs/translate/url', WithDecryption=True)['Parameter']['Value']
    
    return dynamodb.Table(table_name), sqs, queue_url

news_table, sqs_client, QUEUE_URL = init_aws_resources()

def convert_to_jst(utc_time_str: str) -> datetime:
    """UTC時間文字列をJSTのdatetimeオブジェクトに変換"""
    utc_time = datetime.strptime(utc_time_str, "%a, %d %b %Y %H:%M:%S %Z")
    return utc_time.replace(tzinfo=UTC_TIMEZONE).astimezone(JST_TIMEZONE)

def clean_content(text: str) -> str:
    """HTMLタグとTo learn more以降のテキストを削除"""
    text = re.sub('<.*?>', '', text)
    return text.split("To learn more")[0].strip() if "To learn more" in text else text.strip()

def create_article(entry: Dict[str, Any], fetch_date: str) -> Dict[str, Any]:
    """フィードエントリーから記事データを作成"""
    published_jst = convert_to_jst(entry.get('published', datetime.now().strftime("%a, %d %b %Y %H:%M:%S %Z")))
    
    return {
        'タイトル': entry.get('title', 'タイトルなし'),
        'link': entry.get('link', ''),
        '公開日': published_jst.strftime('%Y/%m/%d'),
        '取得日': fetch_date,
        '本文': clean_content(entry.get('description', '')),
        'TimeToExist': int((datetime.now() + timedelta(days=DEFAULT_TTL_DAYS)).timestamp())
    }

def get_rss_feed() -> List[Dict[str, Any]]:
    """RSSフィードから記事を取得"""
    try:
        feed = feedparser.parse(RSS_FEED_URL)
        fetch_date = datetime.now(JST_TIMEZONE).strftime('%Y/%m/%d')
        return [create_article(entry, fetch_date) for entry in feed.entries]
    except Exception as e:
        print(f"RSSフィード取得エラー: {e}")
        return []

def save_and_queue_article(article: Dict[str, Any]) -> bool:
    """記事をDynamoDBに保存しSQSに送信"""
    try:
        news_table.put_item(
            Item=article,
            ConditionExpression='attribute_not_exists(link)'
        )
        sqs_client.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(article, ensure_ascii=False)
        )
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return False
        print(f"記事の保存/送信エラー: {e}")
        return False
    except Exception as e:
        print(f"記事の保存/送信エラー: {e}")
        return False

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        articles = get_rss_feed()
        new_articles = [article for article in articles if save_and_queue_article(article)]
        
        print(f"新規記事数: {len(new_articles)}/{len(articles)}")
        if new_articles:
            print("取得した記事:", json.dumps(new_articles, ensure_ascii=False, indent=2))
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': f'{len(articles)}件の記事を処理'})
        }
    except Exception as e:
        print(f"Lambda実行エラー: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
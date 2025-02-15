import json
import boto3
import urllib.request
from datetime import datetime
from decimal import Decimal
from boto3.dynamodb.conditions import Key
from typing import List, Dict, Any, Optional

# 定数定義
class Config:
    """設定値の管理"""
    LINE_API_URL = 'https://api.line.me/v2/bot/message/broadcast'
    DATE_FORMAT = '%Y/%m/%d'
    SEPARATOR = '-' * 30

class AWSResources:
    """AWSリソースの初期化と管理"""
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.article_table = self.init_table()

    def get_parameter(self, parameter_name: str) -> str:
        """Parameter Storeからパラメータを取得"""
        return boto3.client('ssm').get_parameter(
            Name=parameter_name, 
            WithDecryption=True
        )['Parameter']['Value']

    def init_table(self):
        """DynamoDBテーブルの初期化"""
        table_name = self.get_parameter('/what-aws-news/dynamodb/article/table-name')
        return self.dynamodb.Table(table_name)

class LineNotifier:
    """LINE通知の管理"""
    MAX_ARTICLES_PER_MESSAGE = 10  # 1メッセージあたりの最大記事数
    
    def __init__(self, aws_resources: AWSResources):
        self.aws = aws_resources
        self.token = self._get_token()

    def _get_token(self) -> Optional[str]:
        """LINE Access Tokenを取得"""
        try:
            return self.aws.get_parameter('/what-aws-news/Line_Access_Token')
        except Exception as e:
            print(f"Error getting LINE token: {e}")
            return None

    def _build_message(self, articles: List[Dict[str, Any]], start_index: int, total_articles: int) -> str:
        """通知メッセージを構築"""
        today = datetime.now().strftime(Config.DATE_FORMAT)
        batch_size = len(articles)
        
        # メッセージの冒頭部分を構築
        if total_articles > self.MAX_ARTICLES_PER_MESSAGE:
            range_text = f"{start_index + 1}件目" if batch_size == 1 else f"{start_index + 1}～{start_index + batch_size}件目"
            if start_index == 0:
                message = f"{today}の更新は{total_articles}件でした\n({range_text}を表示)\n\n"
            else:
                message = f"({range_text}を表示)\n\n"
        else:
            message = f"{today}の更新は{total_articles}件でした\n\n"
        
        # 記事の詳細を追加
        for i, article in enumerate(articles, 1):
            message += f"""
📢
{article['翻訳タイトル']}

📝 
{article['翻訳本文']}

🌐 詳細はこちら
{article['link']}

{Config.SEPARATOR if i < len(articles) else ''}\n\n"""
        
        return message.strip()

    def send_message(self, articles: List[Dict[str, Any]]) -> bool:
        """LINE通知を送信（バッチ処理対応）"""
        if not articles:
            print("通知対象の記事がありません")
            return False
            
        if not self.token:
            print("LINE token not found")
            return False

        total_articles = len(articles)
        success = True

        # 記事を10件ずつのバッチに分割して送信
        for i in range(0, total_articles, self.MAX_ARTICLES_PER_MESSAGE):
            batch_articles = articles[i:i + self.MAX_ARTICLES_PER_MESSAGE]
            
            data = {
                'messages': [{
                    'type': 'text',
                    'text': self._build_message(batch_articles, i, total_articles)
                }]
            }
            
            try:
                req = urllib.request.Request(
                    Config.LINE_API_URL,
                    data=json.dumps(data).encode('utf-8'),
                    headers={
                        'Content-Type': 'application/json',
                        'Authorization': f'Bearer {self.token}'
                    },
                    method='POST'
                )
                
                with urllib.request.urlopen(req) as response:
                    batch_success = response.status == 200
                    if batch_success:
                        print(f"LINE message sent successfully (記事 {i+1}～{i+len(batch_articles)}件目)")
                    else:
                        print(f"LINE API error: {response.status}")
                        success = False
                        
            except Exception as e:
                print(f"Error sending LINE message: {e}")
                success = False

        return success

class ArticleManager:
    """記事データの管理"""
    def __init__(self, aws_resources: AWSResources):
        self.table = aws_resources.article_table

    def get_todays_articles(self) -> List[Dict[str, Any]]:
        """今日の記事を取得"""
        try:
            today = datetime.now().strftime(Config.DATE_FORMAT)
            print(f"検索対象の日付: {today}")
            
            response = self.table.query(
                IndexName='publish-date',
                KeyConditionExpression=Key('取得日').eq(today)
            )
                    
            translated_articles = [
                item for item in response['Items']
                if '翻訳タイトル' in item and '翻訳本文' in item
            ]
            
            print(f"今日({today})の記事数: {len(response['Items'])}")
            print(f"翻訳済みの記事数: {len(translated_articles)}")
            
            return translated_articles
            
        except Exception as e:
            print(f"DynamoDB取得エラー: {e}")
            return []

def json_serializer(obj):
    """JSON シリアライザ"""
    if isinstance(obj, Decimal):
        return int(obj)
    raise TypeError(f'Type {type(obj)} is not serializable')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        print("=== LINE通知処理開始 ===")
        
        # リソースの初期化
        aws = AWSResources()
        article_manager = ArticleManager(aws)
        line_notifier = LineNotifier(aws)
        
        # 記事の取得と通知
        articles = article_manager.get_todays_articles()
        if not articles:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': '通知対象の記事がありません'})
            }
        
        notification_success = line_notifier.send_message(articles)
        status_code = 200 if notification_success else 500
        
        return {
            'statusCode': status_code,
            'body': json.dumps({
                'message': f'{len(articles)}件の記事を通知しました' if notification_success else 'LINE通知に失敗しました',
                'articles': articles
            }, ensure_ascii=False, default=json_serializer)
        }

    except Exception as e:
        error_msg = f"エラーが発生しました: {e}"
        print(error_msg)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg}, ensure_ascii=False)
        }
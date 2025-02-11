import json
import boto3
import time
from datetime import datetime
from typing import Dict, Any, Optional, Set

# AWS クライアントの初期化
def init_aws_clients():
    """AWS クライアントの初期化"""
    return {
        'bedrock': boto3.client('bedrock-runtime'),
        'dynamodb': boto3.resource('dynamodb'),
        'sqs': boto3.client('sqs'),
        'article_table': boto3.resource('dynamodb').Table(get_parameter('/what-aws-news/dynamodb/article/table-name'))
    }

def get_parameter(parameter_name: str) -> str:
    """Parameter Storeからパラメータを取得"""
    return boto3.client('ssm').get_parameter(Name=parameter_name, WithDecryption=True)['Parameter']['Value']

# AWS リソースの初期化
aws = init_aws_clients()
QUEUE_URL = get_parameter('/what-aws-news/sqs/translate/url')

def translate_with_bedrock(text: str, content_type: str = "不明") -> Optional[str]:
    """Bedrockを使用してテキストを翻訳"""
    print(f"\n=== {content_type}の処理を開始 ===")
    
    prompts = {
        "タイトル": f"""Please translate the following English text to Japanese and make it concise like a news headline. 
Follow these rules:
1. Remove any unnecessary words at the end (e.g., 'になりました', 'しました', etc.)
2. End with shorter phrases like 'に対応', '利用可能に', '開始', etc.
3. Keep it concise while maintaining the key information
4. Only return the translated text without any explanations

Text to translate:
{text}""",
        "本文": f"""Please follow these steps:
1. Translate the following English text to Japanese
2. Then summarize the translated content in 2-3 concise sentences
3. Return only the summary in Japanese, without any explanations or original text

Text to process:
{text}"""
    }
    
    prompt_text = prompts.get(content_type)
    if not prompt_text:
        print(f"未対応のcontent_type: {content_type}")
        return None

    try:
        for attempt in range(4):
            try:
                response = aws['bedrock'].invoke_model(
                    modelId="anthropic.claude-3-5-sonnet-20240620-v1:0",
                    body=json.dumps({
                        "anthropic_version": "bedrock-2023-05-31",
                        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt_text}]}],
                        "max_tokens": 4000,
                        "temperature": 0
                    })
                )
                
                result = json.loads(response['body'].read())['content'][0]['text'].strip()
                print(f"処理結果: {result}")
                return result

            except Exception as e:
                wait_time = 3 * (3 ** attempt)
                print(f"試行{attempt + 1}/4 - エラー: {str(e)}")
                
                if 'ThrottlingException' in str(e) and attempt < 3:
                    print(f"{wait_time}秒待機します...")
                    time.sleep(wait_time)
                    continue
                return None

    except Exception as e:
        print(f"翻訳エラー（{content_type}）: {e}")
        return None

def update_dynamodb_item(article_data: Dict[str, Any]) -> bool:
    """DynamoDBの記事データを更新"""
    try:
        # 翻訳情報の更新
        updated = aws['article_table'].update_item(
            Key={'link': article_data['link'], '公開日': article_data['公開日']},
            UpdateExpression='SET #tt = :title, #ts = :summary REMOVE #t, #b',
            ExpressionAttributeNames={
                '#tt': '翻訳タイトル',
                '#ts': '翻訳本文',
                '#t': 'タイトル',
                '#b': '本文'
            },
            ExpressionAttributeValues={
                ':title': article_data['translated_title'],
                ':summary': article_data['translated_summary']
            },
            ReturnValues='ALL_NEW'
        )
        return bool(updated.get('Attributes'))
    except Exception as e:
        print(f"DynamoDB更新エラー: {e}")
        return False

def process_message(record: Dict[str, Any], processed_messages: Set[str]) -> bool:
    """SQSメッセージの処理"""
    message_id = record['messageId']
    if message_id in processed_messages:
        print(f"メッセージ {message_id} は既に処理済み")
        return False
        
    processed_messages.add(message_id)
    message_body = json.loads(record['body'])
    
    # 翻訳処理
    translated_title = translate_with_bedrock(message_body['タイトル'], "タイトル")
    time.sleep(30)  # APIレート制限回避
    translated_summary = translate_with_bedrock(message_body['本文'], "本文")
    
    if not translated_title or not translated_summary:
        return False

    # 更新データの準備
    article_data = {
        'link': message_body['link'],
        '公開日': message_body['公開日'],
        'translated_title': translated_title,
        'translated_summary': translated_summary
    }

    # DynamoDB更新と元データ削除
    if update_dynamodb_item(article_data):
        aws['sqs'].delete_message(
            QueueUrl=QUEUE_URL,
            ReceiptHandle=record['receiptHandle']
        )
        return True
    return False

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    start_time = datetime.now()
    
    try:
        print("\n=== 翻訳処理開始 ===")
        processed_messages: Set[str] = set()
        processed_count = sum(1 for record in event['Records'] if process_message(record, processed_messages))
        
        execution_time = (datetime.now() - start_time).total_seconds()
        print(f"=== 翻訳処理終了 === 実行時間: {execution_time:.2f}秒\n")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'{processed_count}件のメッセージを処理しました',
                'execution_time': f"{execution_time:.2f}秒"
            }, ensure_ascii=False)
        }

    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f"エラーが発生しました: {e}",
                'execution_time': f"{execution_time:.2f}秒"
            }, ensure_ascii=False)
        }
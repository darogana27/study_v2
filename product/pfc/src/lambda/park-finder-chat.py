import json
import os
import boto3
from typing import Dict, List, Any
from datetime import datetime
from decimal import Decimal

# AWS クライアントの初期化
dynamodb = boto3.resource('dynamodb')
bedrock_runtime = boto3.client('bedrock-runtime', region_name='ap-northeast-1')

# 環境変数
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'pfc-ParkingSpots-table')
MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')

# システムプロンプト
SYSTEM_PROMPT = """あなたは池袋エリアの駐輪場案内アシスタントです。
ユーザーの質問に対して、提供された駐輪場データから最適な駐輪場を提案してください。

以下の点を考慮して回答してください：
- 空き状況（available/total）
- 距離と徒歩時間
- 料金（時間/日/月）
- 営業時間
- 対応車種

回答は親切で分かりやすく、絵文字を適度に使用してフレンドリーにしてください。
必ず具体的な駐輪場名を挙げて提案してください。"""


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    メインのLambdaハンドラー
    """
    try:
        # リクエストボディの解析
        body = json.loads(event.get('body', '{}'))
        user_message = body.get('message', '')
        
        if not user_message:
            return create_response(400, {'error': 'メッセージが必要です'})
        
        # DynamoDBから駐輪場データを取得
        parking_data = get_parking_data()
        
        # フォールバック応答を使用（Bedrock設定後に修正予定）
        response_data = get_fallback_response(user_message, parking_data)
        
        return create_response(200, response_data)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return create_response(500, {
            'error': 'エラーが発生しました',
            'message': 'しばらく時間をおいて再度お試しください'
        })


def get_parking_data() -> List[Dict[str, Any]]:
    """
    DynamoDBから駐輪場データを取得
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        response = table.scan()
        items = response.get('Items', [])
        
        # Decimalを通常の数値に変換
        return [convert_decimal(item) for item in items]
        
    except Exception as e:
        print(f"DynamoDB Error: {str(e)}")
        return []


def convert_decimal(obj: Any) -> Any:
    """
    DynamoDBのDecimal型を通常の数値型に変換
    """
    if isinstance(obj, list):
        return [convert_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_decimal(value) for key, value in obj.items()}
    elif isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        else:
            return float(obj)
    else:
        return obj


def generate_bedrock_response(user_message: str, parking_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Bedrockを使用してチャット応答を生成
    """
    # 駐輪場データを文字列化
    parking_data_str = '\n'.join([
        f"- {p['name']}: 空き{p['capacity']['available']}/{p['capacity']['total']}台, "
        f"徒歩{p['walkTime']}分({p['distance']}m), {p['fees']['daily']}円/日, {p['openHours']}"
        for p in parking_data
    ])
    
    # プロンプトの構築
    prompt = f"""{SYSTEM_PROMPT}

現在の駐輪場データ：
{parking_data_str}

ユーザーの質問: {user_message}

この質問に対して、最適な駐輪場を提案してください。
また、応答には以下のJSON形式で返してください：
{{
    "message": "ユーザーへの応答メッセージ",
    "recommendedParkingIds": ["推奨する駐輪場のID（最大3つ）"],
    "searchType": "available|nearest|cheapest|24hours|general"
}}"""
    
    try:
        # Bedrock API呼び出し
        response = bedrock_runtime.invoke_model(
            modelId=MODEL_ID,
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1000,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                "temperature": 0.7,
                "top_p": 0.9
            })
        )
        
        # レスポンスの解析
        response_body = json.loads(response['body'].read())
        claude_response = json.loads(response_body['content'][0]['text'])
        
        # 推奨された駐輪場の詳細情報を取得
        recommended_lots = [
            p for p in parking_data 
            if p['id'] in claude_response['recommendedParkingIds']
        ]
        
        # サジェスションを生成
        suggestions = generate_suggestions(claude_response['searchType'])
        
        return {
            'response': claude_response['message'],
            'type': claude_response['searchType'],
            'parkingLots': recommended_lots,
            'suggestions': suggestions,
            'totalFound': len(recommended_lots)
        }
        
    except Exception as e:
        print(f"Bedrock Error: {str(e)}")
        # フォールバック処理
        return get_fallback_response(user_message, parking_data)


def generate_suggestions(search_type: str) -> List[str]:
    """
    検索タイプに応じたサジェスションを生成
    """
    suggestion_map = {
        'available': ['もっと空いている場所', '24時間営業', '料金が安い順'],
        'nearest': ['空き状況を確認', '料金を比較', '営業時間を確認'],
        'cheapest': ['一番近い場所', '空き状況を確認', '月極料金'],
        '24hours': ['空いている場所', '駅から近い順', '料金を確認'],
        'general': ['空いている駐輪場', '一番近い駐輪場', '24時間営業', '料金が安い順']
    }
    
    return suggestion_map.get(search_type, suggestion_map['general'])


def get_fallback_response(message: str, parking_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Bedrockが失敗した場合のフォールバック処理
    """
    lower_message = message.lower()
    
    # キーワードベースの簡易マッチング
    if '空' in message or '空き' in message or 'available' in lower_message:
        available = sorted(
            [p for p in parking_data if p['capacity']['available'] > 10],
            key=lambda x: x['capacity']['available'],
            reverse=True
        )[:3]
        
        return {
            'response': f'現在、{len(available)}件の駐輪場に空きがあります！🚲',
            'type': 'available',
            'parkingLots': available,
            'suggestions': ['もっと空いている場所', '24時間営業', '料金が安い順']
        }
    
    elif '近' in message or '最寄' in message or 'nearest' in lower_message:
        nearest = sorted(parking_data, key=lambda x: x['distance'])[:3]
        
        return {
            'response': '池袋駅から近い順に表示します',
            'type': 'nearest',
            'parkingLots': nearest,
            'suggestions': ['空き状況を確認', '料金を比較', '営業時間を確認']
        }
    
    elif '安' in message or 'cheap' in lower_message or '料金' in message:
        cheapest = sorted(parking_data, key=lambda x: x['fees']['daily'])[:3]
        
        return {
            'response': '料金が安い順に表示します（1日料金）',
            'type': 'cheapest',
            'parkingLots': cheapest,
            'suggestions': ['一番近い場所', '空き状況を確認', '月極料金']
        }
    
    elif '24時間' in message or '深夜' in message or '夜' in message:
        all_day = [p for p in parking_data if '24時間' in p['openHours']]
        
        return {
            'response': f'24時間営業の駐輪場が{len(all_day)}件見つかりました',
            'type': '24hours',
            'parkingLots': all_day,
            'suggestions': ['空いている場所', '駅から近い順', '料金を確認']
        }
    
    # デフォルト応答
    return {
        'response': '池袋エリアの駐輪場をご案内します。どのような条件でお探しですか？',
        'type': 'general',
        'parkingLots': parking_data[:3],
        'suggestions': ['空いている駐輪場', '一番近い駐輪場', '24時間営業', '料金が安い順']
    }


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    API Gatewayレスポンスを作成
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body, ensure_ascii=False)
    }
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
    自然言語処理による高度なチャット機能
    """
    # メッセージを正規化
    lower_message = message.lower()
    
    # より自然な挨拶や基本的な質問への対応
    greetings = ['こんにちは', 'こんばんは', 'おはよう', 'はじめまして', 'お疲れ']
    if any(greeting in message for greeting in greetings):
        return {
            'response': 'こんにちは！池袋エリアの駐輪場案内アシスタントです😊 どちらの駐輪場をお探しですか？',
            'type': 'greeting',
            'parkingLots': parking_data[:3],
            'suggestions': ['空いている場所を探す', '近い場所を探す', '安い場所を探す', '24時間営業']
        }
    
    # ありがとうへの応答
    thanks = ['ありがと', 'サンキュー', 'thanks', 'thank you']
    if any(thank in lower_message for thank in thanks):
        return {
            'response': 'どういたしまして！他にもご質問があればお気軽にどうぞ🚲✨',
            'type': 'thanks',
            'parkingLots': [],
            'suggestions': ['別の条件で探す', '営業時間を確認', '料金を比較', 'おすすめの駐輪場']
        }
    
    # 場所・距離に関する質問
    location_keywords = ['近', '最寄', '駅', '徒歩', '歩い', '距離', 'アクセス', '行き方']
    if any(keyword in message for keyword in location_keywords):
        nearest = sorted(parking_data, key=lambda x: x['distance'])[:3]
        responses = [
            f'池袋駅から一番近いのは{nearest[0]["name"]}です！徒歩{nearest[0]["walkTime"]}分です🚶‍♂️',
            f'アクセス重視でしたら{nearest[0]["name"]}がおすすめです。{nearest[0]["distance"]}mの距離です📍',
            f'近場の駐輪場をお探しですね！{len(nearest)}ヶ所ご紹介します🗺️'
        ]
        import random
        return {
            'response': random.choice(responses),
            'type': 'nearest',
            'parkingLots': nearest,
            'suggestions': ['空き状況を確認', '料金を比較', '営業時間を確認', '他の条件で探す']
        }
    
    # 空き状況に関する質問
    availability_keywords = ['空', '空い', '利用可能', '使える', '止められ', '満車', '混雑', 'available']
    if any(keyword in message for keyword in availability_keywords):
        available = sorted(
            [p for p in parking_data if p['capacity']['available'] > 10],
            key=lambda x: x['capacity']['available'],
            reverse=True
        )[:3]
        
        responses = [
            f'今なら{len(available)}ヶ所で空きがあります！一番空いているのは{available[0]["name"]}です🟢',
            f'空き状況をチェックしました！{available[0]["name"]}が{available[0]["capacity"]["available"]}台空いてておすすめです🚲',
            f'リアルタイムデータでは{len(available)}ヶ所に余裕があります✨'
        ]
        import random
        return {
            'response': random.choice(responses),
            'type': 'available',
            'parkingLots': available,
            'suggestions': ['もっと空いている場所', '24時間営業', '料金を確認', '近い場所']
        }
    
    # 料金に関する質問
    price_keywords = ['安', '料金', '値段', '費用', 'コスト', '価格', 'お金', '円', 'cheap', 'cost']
    if any(keyword in message for keyword in price_keywords):
        cheapest = sorted(parking_data, key=lambda x: x['fees']['daily'])[:3]
        responses = [
            f'お財布に優しい駐輪場をご紹介！{cheapest[0]["name"]}が1日{cheapest[0]["fees"]["daily"]}円です💰',
            f'料金重視でしたら{cheapest[0]["name"]}がおすすめです。1日{cheapest[0]["fees"]["daily"]}円でリーズナブルです💴',
            f'コスパの良い駐輪場を{len(cheapest)}ヶ所ピックアップしました！'
        ]
        import random
        return {
            'response': random.choice(responses),
            'type': 'cheapest',
            'parkingLots': cheapest,
            'suggestions': ['一番近い場所', '空き状況を確認', '月極料金', '24時間営業']
        }
    
    # 時間・営業時間に関する質問
    time_keywords = ['24時間', '深夜', '夜', '朝', '営業時間', '何時', 'いつまで', '時間', 'hours']
    if any(keyword in message for keyword in time_keywords):
        all_day = [p for p in parking_data if '24時間' in p['openHours']]
        if '24時間' in message or '深夜' in message or '夜' in message:
            responses = [
                f'夜でも安心！24時間営業の駐輪場が{len(all_day)}ヶ所あります🌙',
                f'深夜利用OK！{all_day[0]["name"]}など{len(all_day)}ヶ所が24時間対応です⭐',
                f'いつでも利用できる駐輪場をご案内します🕐'
            ]
        else:
            responses = [
                f'営業時間をお調べしました！各駐輪場の営業時間は詳細でご確認ください🕐',
                f'時間を気にせず使いたいなら24時間営業がおすすめです！',
                f'営業時間は駐輪場によって異なります。詳細をチェックしてみてください📅'
            ]
        import random
        return {
            'response': random.choice(responses),
            'type': '24hours',
            'parkingLots': all_day if all_day else parking_data[:3],
            'suggestions': ['空いている場所', '駅から近い順', '料金を確認', '他の条件']
        }
    
    # 推奨・おすすめに関する質問
    recommend_keywords = ['おすすめ', 'オススメ', '推奨', 'いい', '良い', 'ベスト', '人気', 'recommend']
    if any(keyword in message for keyword in recommend_keywords):
        # バランスの良い駐輪場を選出（距離、空き、料金を総合評価）
        scored_parking = []
        for p in parking_data:
            distance_score = (400 - p['distance']) / 400 * 100  # 距離が近いほど高得点
            availability_score = (p['capacity']['available'] / p['capacity']['total']) * 100  # 空きが多いほど高得点
            price_score = (800 - p['fees']['daily']) / 800 * 100  # 料金が安いほど高得点
            total_score = (distance_score + availability_score + price_score) / 3
            scored_parking.append((p, total_score))
        
        best = sorted(scored_parking, key=lambda x: x[1], reverse=True)[:3]
        best_parking = [p[0] for p in best]
        
        responses = [
            f'総合的におすすめは{best_parking[0]["name"]}です！バランスが良くて使いやすいですよ👍',
            f'いろんな条件を考慮すると{best_parking[0]["name"]}がイチオシです✨',
            f'人気のバランス型駐輪場をご紹介！{len(best_parking)}ヶ所セレクトしました🏆'
        ]
        import random
        return {
            'response': random.choice(responses),
            'type': 'recommend',
            'parkingLots': best_parking,
            'suggestions': ['条件別に探す', '空き状況を確認', '料金を比較', '営業時間を確認']
        }
    
    # 具体的な駐輪場名が含まれている場合
    parking_names = [p['name'] for p in parking_data]
    mentioned_parking = [p for p in parking_data if any(name_part in message for name_part in p['name'].split())]
    if mentioned_parking:
        target = mentioned_parking[0]
        occupancy = target['capacity']['available']
        total = target['capacity']['total']
        rate = int((total - occupancy) / total * 100)
        
        status_emoji = '🟢' if rate < 50 else '🟡' if rate < 80 else '🔴'
        responses = [
            f'{target["name"]}ですね！現在{occupancy}台空きがあります{status_emoji}',
            f'{target["name"]}の状況をお調べしました。混雑率{rate}%です📊',
            f'{target["name"]}は{target["address"]}にあり、1日{target["fees"]["daily"]}円です💼'
        ]
        import random
        return {
            'response': random.choice(responses),
            'type': 'specific',
            'parkingLots': [target],
            'suggestions': ['他の駐輪場と比較', '詳細情報を確認', '営業時間', '料金プラン']
        }
    
    # 質問の意図が不明な場合の親切な応答
    responses = [
        '申し訳ありません、どのような駐輪場をお探しでしょうか？🤔 もう少し詳しく教えていただけますか？',
        'すみません、うまく理解できませんでした💦 「近い場所」「安い場所」「空いている場所」など、条件を教えてください！',
        'どんな駐輪場をお探しですか？😊 場所、料金、営業時間など、ご希望をお聞かせください！',
        'お探しの条件を教えてください！池袋エリアの駐輪場をご案内します🚲✨'
    ]
    import random
    return {
        'response': random.choice(responses),
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
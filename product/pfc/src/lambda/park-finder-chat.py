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
MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-haiku-20240307-v1:0')
ENABLE_SELECTION_MODE = os.environ.get('ENABLE_SELECTION_MODE', 'true').lower() == 'true'
MAX_BEDROCK_TOKENS = int(os.environ.get('MAX_BEDROCK_TOKENS', '150'))
ENABLE_TOKYO_WIDE = os.environ.get('ENABLE_TOKYO_WIDE', 'true').lower() == 'true'

# 選択肢マッピング
SELECTION_MAPPING = {
    'step1': {
        'park': {'category': 'park', 'keywords': ['公園', '自然']},
        'station': {'category': 'station', 'keywords': ['駅', '電車', '交通']},
        'shopping': {'category': 'shopping', 'keywords': ['商業', 'ショッピング', '買い物']},
        'hospital': {'category': 'facility', 'keywords': ['病院', '施設', '公的']}
    },
    'step2': {
        'free': {'priority': 'cost', 'filter': {'fee_type': 'free'}},
        'cheap': {'priority': 'cost', 'filter': {'fee_max': 300}},
        'near_station': {'priority': 'distance', 'filter': {'distance_max': 200}},
        'motorcycle': {'priority': 'vehicle', 'filter': {'bike_types': '原付'}},
        'bicycle': {'priority': 'vehicle', 'filter': {'bike_types': '自転車'}}
    },
    'step3': {
        # 山手線主要駅
        'shinjuku': {'area': 'shinjuku', 'ward': '新宿区', 'station': '新宿', 'coordinates': {'lat': 35.6896, 'lng': 139.7006}},
        'shibuya': {'area': 'shibuya', 'ward': '渋谷区', 'station': '渋谷', 'coordinates': {'lat': 35.6580, 'lng': 139.7016}},
        'ikebukuro': {'area': 'ikebukuro', 'ward': '豊島区', 'station': '池袋', 'coordinates': {'lat': 35.7295, 'lng': 139.7109}},
        'tokyo': {'area': 'tokyo', 'ward': '千代田区', 'station': '東京', 'coordinates': {'lat': 35.6812, 'lng': 139.7671}},
        'shinagawa': {'area': 'shinagawa', 'ward': '港区', 'station': '品川', 'coordinates': {'lat': 35.6284, 'lng': 139.7387}},
        'ueno': {'area': 'ueno', 'ward': '台東区', 'station': '上野', 'coordinates': {'lat': 35.7138, 'lng': 139.7772}},
        
        # その他主要駅
        'kichijoji': {'area': 'kichijoji', 'ward': '武蔵野市', 'station': '吉祥寺', 'coordinates': {'lat': 35.7032, 'lng': 139.5797}},
        'tachikawa': {'area': 'tachikawa', 'ward': '立川市', 'station': '立川', 'coordinates': {'lat': 35.6988, 'lng': 139.4133}},
        'machida': {'area': 'machida', 'ward': '町田市', 'station': '町田', 'coordinates': {'lat': 35.5438, 'lng': 139.4469}},
        
        # 区域選択
        'ward_select': {'area': 'ward_selection', 'use_ward_selection': True},
        'current_location': {'area': 'current', 'use_location': True}
    },
    # 区・市選択マッピング
    'ward_selection': {
        # 23区
        'chiyoda': {'area': 'chiyoda', 'ward': '千代田区'},
        'chuo': {'area': 'chuo', 'ward': '中央区'},
        'minato': {'area': 'minato', 'ward': '港区'},
        'shinjuku_ward': {'area': 'shinjuku', 'ward': '新宿区'},
        'bunkyo': {'area': 'bunkyo', 'ward': '文京区'},
        'taito': {'area': 'taito', 'ward': '台東区'},
        'sumida': {'area': 'sumida', 'ward': '墨田区'},
        'koto': {'area': 'koto', 'ward': '江東区'},
        'shinagawa_ward': {'area': 'shinagawa', 'ward': '品川区'},
        'meguro': {'area': 'meguro', 'ward': '目黒区'},
        'ota': {'area': 'ota', 'ward': '大田区'},
        'setagaya': {'area': 'setagaya', 'ward': '世田谷区'},
        'shibuya_ward': {'area': 'shibuya', 'ward': '渋谷区'},
        'nakano': {'area': 'nakano', 'ward': '中野区'},
        'suginami': {'area': 'suginami', 'ward': '杉並区'},
        'toshima': {'area': 'toshima', 'ward': '豊島区'},
        'kita': {'area': 'kita', 'ward': '北区'},
        'arakawa': {'area': 'arakawa', 'ward': '荒川区'},
        'itabashi': {'area': 'itabashi', 'ward': '板橋区'},
        'nerima': {'area': 'nerima', 'ward': '練馬区'},
        'adachi': {'area': 'adachi', 'ward': '足立区'},
        'katsushika': {'area': 'katsushika', 'ward': '葛飾区'},
        'edogawa': {'area': 'edogawa', 'ward': '江戸川区'},
        
        # 主要市部
        'hachioji': {'area': 'hachioji', 'ward': '八王子市'},
        'tachikawa_city': {'area': 'tachikawa', 'ward': '立川市'},
        'musashino': {'area': 'musashino', 'ward': '武蔵野市'},
        'mitaka': {'area': 'mitaka', 'ward': '三鷹市'},
        'fuchu': {'area': 'fuchu', 'ward': '府中市'},
        'chofu': {'area': 'chofu', 'ward': '調布市'},
        'machida_city': {'area': 'machida', 'ward': '町田市'},
        'nishitokyo': {'area': 'nishitokyo', 'ward': '西東京市'}
    }
}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    メインのLambdaハンドラー - 選択肢型チャット対応
    """
    try:
        body = json.loads(event.get('body', '{}'))
        is_selection_mode = body.get('isSelectionMode', False)
        
        if is_selection_mode and ENABLE_SELECTION_MODE:
            return handle_selection_mode(body)
        else:
            # 従来のフリー入力モード
            user_message = body.get('message', '')
            if not user_message:
                return create_response(400, {'error': 'メッセージが必要です'})
            
            parking_data = get_parking_data()
            response_data = get_fallback_response(user_message, parking_data)
            return create_response(200, response_data)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return create_response(500, {
            'error': 'エラーが発生しました',
            'message': 'しばらく時間をおいて再度お試しください'
        })


def handle_selection_mode(body: Dict[str, Any]) -> Dict[str, Any]:
    """
    選択肢モードの処理 - Bedrockコスト最適化（東京全域対応）
    """
    try:
        selections = body.get('selections', {})
        step = body.get('step', 3)
        area = body.get('area', '')
        ward = body.get('ward', '')
        
        # 区・市選択モードの場合、ward_selectionステップとして処理
        if step == 'ward_selection' or area == 'ward_selection':
            step = 'ward_selection'
        elif step < 3 and step != 'ward_selection':
            return create_response(200, {'error': 'まだ選択が完了していません'})
        
        # 選択情報を解析
        filters = build_filters_from_selections(selections, area, ward)
        
        # DynamoDBから事前フィルタリング（東京全域対応）
        parking_data = get_filtered_parking_data_tokyo_wide(filters)
        
        if not parking_data:
            area_name = ward or area or 'エリア'
            return create_response(200, {
                'response': f'{area_name}で条件に合う駐輪場が見つかりませんでした😅 条件を変更してみてください。',
                'parkingLots': [],
                'suggestions': ['条件を変更', '別のエリア', '新しい検索']
            })
        
        # 最適化されたBedrock呼び出し
        response_data = generate_optimized_bedrock_response(selections, parking_data, area, ward)
        
        return create_response(200, response_data)
        
    except Exception as e:
        print(f"Selection mode error: {str(e)}")
        return create_response(500, {
            'error': '選択処理でエラーが発生しました',
            'response': 'もう一度お試しください'
        })


def build_filters_from_selections(selections: Dict[str, Any], area: str = '', ward: str = '') -> Dict[str, Any]:
    """
    選択情報からDynamoDBフィルタを構築（東京全域対応）
    """
    filters = {}
    
    # Step 1: カテゴリフィルタ
    step1 = selections.get('step1', {})
    if step1 and step1.get('id') in SELECTION_MAPPING['step1']:
        category_info = SELECTION_MAPPING['step1'][step1['id']]
        filters.update(category_info)
    
    # Step 2: 優先度フィルタ
    step2 = selections.get('step2', {})
    if step2 and step2.get('id') in SELECTION_MAPPING['step2']:
        priority_info = SELECTION_MAPPING['step2'][step2['id']]
        filters.update(priority_info)
    
    # Step 3: エリアフィルタ（東京全域対応）
    step3 = selections.get('step3', {})
    if step3 and step3.get('id') in SELECTION_MAPPING['step3']:
        area_info = SELECTION_MAPPING['step3'][step3['id']]
        filters.update(area_info)
    
    # 区・市選択フィルタ
    if area and ward:
        filters['area'] = area
        filters['ward'] = ward
    elif ward:
        filters['ward'] = ward
    elif area and area != 'ward_selection':
        filters['area'] = area
    
    return filters


def get_filtered_parking_data_tokyo_wide(filters: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    東京全域対応のフィルタに基づいてDynamoDBから駐輪場データを取得
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        # 東京全域モードが無効な場合は従来の処理
        if not ENABLE_TOKYO_WIDE:
            return get_filtered_parking_data(filters)
        
        # 区・駅・エリア指定がある場合はGSIを使用
        ward = filters.get('ward')
        station = filters.get('station')
        area = filters.get('area')
        
        items = []
        
        if ward:
            # WardIndexを使用した効率的検索
            response = table.query(
                IndexName='WardIndex',
                KeyConditionExpression='ward = :ward',
                ExpressionAttributeValues={':ward': ward},
                Limit=100
            )
            items = response.get('Items', [])
        elif station:
            # StationIndexを使用した効率的検索
            response = table.query(
                IndexName='StationIndex',
                KeyConditionExpression='station = :station',
                ExpressionAttributeValues={':station': station},
                Limit=100
            )
            items = response.get('Items', [])
        elif area and area in ['shinjuku', 'shibuya', 'ikebukuro', 'tokyo', 'shinagawa', 'ueno']:
            # 主要駅エリアでの検索
            station_name = {'shinjuku': '新宿', 'shibuya': '渋谷', 'ikebukuro': '池袋', 
                           'tokyo': '東京', 'shinagawa': '品川', 'ueno': '上野'}.get(area, area)
            response = table.query(
                IndexName='StationIndex',
                KeyConditionExpression='station = :station',
                ExpressionAttributeValues={':station': station_name},
                Limit=100
            )
            items = response.get('Items', [])
        else:
            # 全体スキャン（制限付き）
            response = table.scan(Limit=200)
            items = response.get('Items', [])
        
        # フィルタリング適用
        filtered_items = []
        for item in items:
            item = convert_decimal(item)
            
            # 料金フィルタ
            if 'fee_type' in filters:
                if filters['fee_type'] == 'free':
                    fees = item.get('fees', {})
                    if fees.get('daily', 999) > 0 and fees.get('hourly', 999) > 0:
                        continue
            
            if 'fee_max' in filters:
                daily_fee = item.get('fees', {}).get('daily', 999)
                if daily_fee > filters['fee_max']:
                    continue
            
            # 距離フィルタ
            if 'distance_max' in filters:
                if item.get('distance', 999) > filters['distance_max']:
                    continue
            
            # 車種フィルタ
            if 'bike_types' in filters:
                vehicle_types = item.get('vehicleTypes', [])
                if not vehicle_types:
                    vehicle_types = item.get('bikeTypes', [])  # 旧フィールド名対応
                
                if filters['bike_types'] not in ' '.join(vehicle_types):
                    continue
            
            filtered_items.append(item)
        
        # 優先度に基づいてソート
        priority = filters.get('priority', 'distance')
        if priority == 'cost':
            filtered_items.sort(key=lambda x: x.get('fees', {}).get('daily', 999))
        elif priority == 'distance':
            filtered_items.sort(key=lambda x: x.get('distance', 999))
        
        return filtered_items[:15]  # 最大15件
        
    except Exception as e:
        print(f"Tokyo-wide filtering error: {str(e)}")
        # フォールバック：従来の検索
        return get_filtered_parking_data(filters)


def get_filtered_parking_data(filters: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    フィルタに基づいてDynamoDBから駐輪場データを取得
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        # 基本スキャン
        response = table.scan(Limit=50)  # 最大50件に制限
        items = response.get('Items', [])
        
        # フィルタリング適用
        filtered_items = []
        for item in items:
            item = convert_decimal(item)
            
            # 料金フィルタ
            if 'fee_type' in filters:
                if filters['fee_type'] == 'free' and item.get('fees', {}).get('daily', 999) > 0:
                    continue
            
            if 'fee_max' in filters:
                if item.get('fees', {}).get('daily', 999) > filters['fee_max']:
                    continue
            
            # 距離フィルタ
            if 'distance_max' in filters:
                if item.get('distance', 999) > filters['distance_max']:
                    continue
            
            # 車種フィルタ
            if 'bike_types' in filters:
                bike_types = item.get('bikeTypes', [])
                if filters['bike_types'] not in ' '.join(bike_types):
                    continue
            
            filtered_items.append(item)
        
        # 優先度に基づいてソート
        priority = filters.get('priority', 'distance')
        if priority == 'cost':
            filtered_items.sort(key=lambda x: x.get('fees', {}).get('daily', 999))
        elif priority == 'distance':
            filtered_items.sort(key=lambda x: x.get('distance', 999))
        
        return filtered_items[:10]  # 最大10件
        
    except Exception as e:
        print(f"Filtering error: {str(e)}")
        return []


def generate_optimized_bedrock_response(selections: Dict[str, Any], parking_data: List[Dict[str, Any]], area: str = '', ward: str = '') -> Dict[str, Any]:
    """
    最適化されたBedrock応答生成 - 東京全域対応、コスト削減重視
    """
    if not parking_data:
        area_display = ward or area or 'エリア'
        return {
            'response': f'{area_display}で条件に合う駐輪場が見つかりませんでした。',
            'parkingLots': [],
            'suggestions': ['条件変更', '別のエリアを試す', '新しい検索']
        }
    
    # 超短縮プロンプト - 東京全域対応
    step2_choice = selections.get('step2', {}).get('text', '一般的な')
    
    # エリア表示の決定（区・市 > step3選択 > area）
    location_choice = ward or selections.get('step3', {}).get('text', area or 'エリア')
    
    # 駐輪場データを最小限に（東京全域データに対応）
    compact_data = []
    for p in parking_data[:5]:  # 最大5件
        # 新しいスキーマ対応（capacity、walkTime、fees構造）
        available = p.get('capacity', {}).get('available', p.get('available', 0))
        total = p.get('capacity', {}).get('total', p.get('total', 0))
        walk_time = p.get('walkTime', p.get('walk_time', 0))
        daily_fee = p.get('fees', {}).get('daily', p.get('daily_fee', 0))
        
        compact_data.append(f"{p['name']}(空{available}/{total},徒歩{walk_time}分,{daily_fee}円)")
    
    # 東京全域対応の短縮プロンプト
    prompt = f"{step2_choice}重視で{location_choice}の駐輪場。{len(compact_data)}件:{'|'.join(compact_data)}。上位3つ推奨理由各1行"
    
    try:
        response = bedrock_runtime.invoke_model(
            modelId=MODEL_ID,
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": MAX_BEDROCK_TOKENS,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3
            })
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body['content'][0]['text']
        
        return {
            'response': ai_response,
            'parkingLots': parking_data[:3],
            'suggestions': ['別の条件で探す', '詳細を確認', '新しい検索'],
            'type': 'selection_result'
        }
        
    except Exception as e:
        print(f"Bedrock error: {str(e)}")
        # フォールバック（東京全域対応）
        area_display = ward or area or 'エリア'
        return {
            'response': f'{area_display}で{len(parking_data)}件の駐輪場が見つかりました！条件にぴったりの場所をご案内します🎯',
            'parkingLots': parking_data[:3],
            'suggestions': ['別の条件', '詳細確認', '新しい検索'],
            'type': 'selection_result'
        }


def get_parking_data() -> List[Dict[str, Any]]:
    """
    DynamoDBから駐輪場データを取得
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        response = table.scan()
        items = response.get('Items', [])
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
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj


def get_fallback_response(message: str, parking_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    フリー入力モード用のフォールバック応答
    """
    lower_message = message.lower()
    
    # 挨拶
    greetings = ['こんにちは', 'こんばんは', 'おはよう', 'はじめまして']
    if any(greeting in message for greeting in greetings):
        return {
            'response': 'こんにちは！池袋エリアの駐輪場案内アシスタントです😊 選択肢モードで簡単検索できます！',
            'type': 'greeting',
            'parkingLots': parking_data[:3],
            'suggestions': ['🎯 選択肢モードを試す', '空いている場所', '近い場所', '安い場所']
        }
    
    # 距離関連
    location_keywords = ['近', '最寄', '駅', '徒歩', '距離']
    if any(keyword in message for keyword in location_keywords):
        nearest = sorted(parking_data, key=lambda x: x['distance'])[:3]
        return {
            'response': f'池袋駅から一番近いのは{nearest[0]["name"]}です！徒歩{nearest[0]["walkTime"]}分です🚶‍♂️',
            'type': 'nearest',
            'parkingLots': nearest,
            'suggestions': ['空き状況を確認', '料金を比較', '🎯 選択肢モード']
        }
    
    # 空き状況
    availability_keywords = ['空', '空い', '利用可能', '使える']
    if any(keyword in message for keyword in availability_keywords):
        available = sorted(
            [p for p in parking_data if p['capacity']['available'] > 10],
            key=lambda x: x['capacity']['available'],
            reverse=True
        )[:3]
        return {
            'response': f'今なら{len(available)}ヶ所で空きがあります！一番空いているのは{available[0]["name"]}です🟢',
            'type': 'available',
            'parkingLots': available,
            'suggestions': ['もっと空いている場所', '🎯 選択肢モード', '料金を確認']
        }
    
    # デフォルト応答
    return {
        'response': '選択肢モードで簡単に条件を指定できます！🎯 または、「近い場所」「安い場所」など条件を教えてください😊',
        'type': 'general',
        'parkingLots': parking_data[:3],
        'suggestions': ['🎯 選択肢モードを試す', '空いている駐輪場', '一番近い駐輪場', '料金が安い順']
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
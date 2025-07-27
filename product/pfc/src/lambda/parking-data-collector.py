import json
import os
import boto3
from typing import Dict, List, Any
from datetime import datetime
import logging
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'pfc-ParkingSpots-table')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    駐輪場データ収集のメインハンドラー
    """
    try:
        logger.info("Starting parking data collection...")
        
        # データ収集実行
        collected_data = collect_parking_data()
        
        # DynamoDBに保存
        saved_count = save_to_dynamodb(collected_data)
        
        logger.info(f"Successfully processed {saved_count} parking spots")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully updated {saved_count} parking spots',
                'timestamp': datetime.now().isoformat(),
                'processed_count': saved_count
            })
        }
        
    except Exception as e:
        logger.error(f"Error in parking data collection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to collect parking data',
                'message': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }


def collect_parking_data() -> List[Dict[str, Any]]:
    """
    駐輪場データを収集する
    軽量構成では固定データ + 模擬リアルタイムデータを使用
    """
    # 池袋エリアの駐輪場データ（実際の運用時は外部APIから取得）
    mock_parking_data = [
        {
            "id": "ikebukuro-east-1",
            "name": "池袋東口駐輪場",
            "address": "東京都豊島区東池袋1-1-1",
            "lat": 35.7289,
            "lng": 139.7186,
            "distance": 50,
            "walkTime": 1,
            "capacity": {
                "total": 200,
                "available": generate_random_availability(200)
            },
            "fees": {
                "hourly": 100,
                "daily": 500,
                "monthly": 8000
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車", "原付"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "ikebukuro-west-1", 
            "name": "池袋西口駐輪場",
            "address": "東京都豊島区西池袋1-1-1",
            "lat": 35.7289,
            "lng": 139.7094,
            "distance": 80,
            "walkTime": 2,
            "capacity": {
                "total": 300,
                "available": generate_random_availability(300)
            },
            "fees": {
                "hourly": 100,
                "daily": 400,
                "monthly": 7500
            },
            "openHours": "5:00-25:00",
            "vehicleTypes": ["自転車", "原付", "バイク"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "sunshine-city-1",
            "name": "サンシャインシティ駐輪場",
            "address": "東京都豊島区東池袋3-1-1",
            "lat": 35.7285,
            "lng": 139.7183,
            "distance": 300,
            "walkTime": 5,
            "capacity": {
                "total": 150,
                "available": generate_random_availability(150)
            },
            "fees": {
                "hourly": 150,
                "daily": 600,
                "monthly": 9000
            },
            "openHours": "6:00-24:00",
            "vehicleTypes": ["自転車"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "ikebukuro-station-1",
            "name": "池袋駅東地下駐輪場",
            "address": "東京都豊島区東池袋1-1-25",
            "lat": 35.7280,
            "lng": 139.7181,
            "distance": 20,
            "walkTime": 1,
            "capacity": {
                "total": 400,
                "available": generate_random_availability(400)
            },
            "fees": {
                "hourly": 120,
                "daily": 550,
                "monthly": 8500
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車", "原付"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "tobu-parking-1",
            "name": "東武池袋駐輪場",
            "address": "東京都豊島区南池袋1-1-25",
            "lat": 35.7285,
            "lng": 139.7101,
            "distance": 100,
            "walkTime": 2,
            "capacity": {
                "total": 250,
                "available": generate_random_availability(250)
            },
            "fees": {
                "hourly": 100,
                "daily": 450,
                "monthly": 7000
            },
            "openHours": "5:30-24:30",
            "vehicleTypes": ["自転車", "原付"],
            "lastUpdated": datetime.now().isoformat()
        }
    ]
    
    logger.info(f"Generated mock data for {len(mock_parking_data)} parking spots")
    return mock_parking_data


def generate_random_availability(total: int) -> int:
    """
    リアルタイム風の空き状況を生成
    時間帯によって異なる利用率を模擬
    """
    import random
    from datetime import datetime
    
    current_hour = datetime.now().hour
    
    # 時間帯別の利用率（満車率）
    if 7 <= current_hour <= 9:  # 朝の通勤時間
        usage_rate = random.uniform(0.7, 0.9)
    elif 17 <= current_hour <= 19:  # 夕方の帰宅時間
        usage_rate = random.uniform(0.6, 0.8)
    elif 12 <= current_hour <= 14:  # 昼食時間
        usage_rate = random.uniform(0.4, 0.6)
    elif 20 <= current_hour <= 23:  # 夜の時間
        usage_rate = random.uniform(0.3, 0.5)
    else:  # その他の時間
        usage_rate = random.uniform(0.2, 0.4)
    
    used_spots = int(total * usage_rate)
    available = total - used_spots
    
    return max(0, available)


def save_to_dynamodb(parking_data: List[Dict[str, Any]]) -> int:
    """
    DynamoDBにデータを保存
    """
    table = dynamodb.Table(TABLE_NAME)
    saved_count = 0
    
    try:
        with table.batch_writer() as batch:
            for spot in parking_data:
                # DynamoDB用にDecimal変換
                spot_data = convert_floats_to_decimal(spot)
                batch.put_item(Item=spot_data)
                saved_count += 1
                
        logger.info(f"Successfully saved {saved_count} items to DynamoDB")
        return saved_count
        
    except Exception as e:
        logger.error(f"Failed to save to DynamoDB: {str(e)}")
        raise


def convert_floats_to_decimal(obj: Any) -> Any:
    """
    floatをDynamoDB用のDecimalに変換
    """
    if isinstance(obj, list):
        return [convert_floats_to_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_floats_to_decimal(value) for key, value in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    else:
        return obj
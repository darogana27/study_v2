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
    # 池袋エリアの駐輪場データ（実際の駐輪場情報に基づく）
    mock_parking_data = [
        # 池袋駅周辺（東口エリア）
        {
            "id": "toshima-ikebukuro-east",
            "name": "豊島区立池袋駅東自転車駐車場", 
            "address": "東京都豊島区東池袋1-5-6",
            "lat": 35.7287,
            "lng": 139.7161,
            "distance": 30,
            "walkTime": 1,
            "capacity": {
                "total": 550,
                "available": generate_random_availability(550)
            },
            "fees": {
                "hourly": 0,
                "daily": 150,
                "monthly": 8000,
                "freeTime": 120,  # 2時間無料
                "initialFee": 0,
                "initialTime": 120,
                "details": "最初2時間無料、以降1日150円"
            },
            "openHours": "4:00-25:30",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "回数券", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "wilroad-parking",
            "name": "ウイロード自転車駐車場",
            "address": "東京都豊島区東池袋1-1-4",
            "lat": 35.7293,
            "lng": 139.7157,
            "distance": 20,
            "walkTime": 1,
            "capacity": {
                "total": 160,
                "available": generate_random_availability(160)
            },
            "fees": {
                "hourly": 100,
                "daily": 500,
                "monthly": 7500,
                "freeTime": 120,  # 2時間無料
                "initialFee": 0,
                "initialTime": 120,
                "details": "最初2時間無料、以降6時間100円"
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC", "電子マネー"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "parco-parking",
            "name": "池袋パルコ別館P'パルコ駐輪場",
            "address": "東京都豊島区東池袋1-50-35",
            "lat": 35.7298,
            "lng": 139.7149,
            "distance": 50,
            "walkTime": 2,
            "capacity": {
                "total": 88,
                "available": generate_random_availability(88)
            },
            "fees": {
                "hourly": 100,
                "daily": 600,
                "monthly": 8000,
                "freeTime": 60,  # 1時間無料
                "initialFee": 0,
                "initialTime": 60,
                "details": "最初1時間無料、以降5-10時間100円"
            },
            "openHours": "7:00-26:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "クレジットカード", "電子マネー", "QRコード決済"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "plaza-parking",
            "name": "プラザ駐輪場",
            "address": "東京都豊島区東池袋1-7-1",
            "lat": 35.7285,
            "lng": 139.7165,
            "distance": 40,
            "walkTime": 1,
            "capacity": {
                "total": 1470,
                "available": generate_random_availability(1470)
            },
            "fees": {
                "hourly": 0,
                "daily": 150,
                "monthly": 8500,
                "freeTime": 0,
                "initialFee": 150,
                "initialTime": 1440,
                "details": "1日150円"
            },
            "openHours": "7:00-24:30",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "wacca-parking",
            "name": "WACCA駐輪場",
            "address": "東京都豊島区東池袋1-8-1",
            "lat": 35.7301,
            "lng": 139.7173,
            "distance": 80,
            "walkTime": 2,
            "capacity": {
                "total": 120,
                "available": generate_random_availability(120)
            },
            "fees": {
                "hourly": 50,
                "daily": 400,
                "monthly": 7000,
                "freeTime": 0,
                "initialFee": 50,
                "initialTime": 60,
                "details": "60分50円"
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "PayPay", "交通系IC", "電子マネー"],
            "lastUpdated": datetime.now().isoformat()
        },
        
        # サンシャインシティ周辺
        {
            "id": "sunshine-city-west",
            "name": "サンシャインシティ西駐輪場",
            "address": "東京都豊島区東池袋3-1-1",
            "lat": 35.7286,
            "lng": 139.7182,
            "distance": 250,
            "walkTime": 4,
            "capacity": {
                "total": 62,
                "available": generate_random_availability(62)
            },
            "fees": {
                "hourly": 110,
                "daily": 600,
                "monthly": 8500,
                "freeTime": 0,
                "initialFee": 110,
                "initialTime": 180,
                "details": "3時間110円"
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "PayPay", "交通系IC", "電子マネー"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "sunshine-city-main",
            "name": "サンシャインシティ地下駐輪場",
            "address": "東京都豊島区東池袋3-1-2",
            "lat": 35.7289,
            "lng": 139.7186,
            "distance": 300,
            "walkTime": 5,
            "capacity": {
                "total": 180,
                "available": generate_random_availability(180)
            },
            "fees": {
                "hourly": 150,
                "daily": 650,
                "monthly": 9000,
                "freeTime": 30,
                "initialFee": 100,
                "initialTime": 90,
                "details": "最初30分無料、90分まで100円、以降150円/時間"
            },
            "openHours": "6:00-24:00",
            "vehicleTypes": ["自転車", "原付"],
            "paymentMethods": ["現金", "PayPay", "交通系IC", "電子マネー"],
            "lastUpdated": datetime.now().isoformat()
        },
        
        # 池袋西口エリア
        {
            "id": "toshima-ikebukuro-west",
            "name": "豊島区立池袋駅西自転車駐車場",
            "address": "東京都豊島区西池袋1-8-1",
            "lat": 35.7293,
            "lng": 139.7098,
            "distance": 60,
            "walkTime": 2,
            "capacity": {
                "total": 420,
                "available": generate_random_availability(420)
            },
            "fees": {
                "hourly": 0,
                "daily": 100,
                "monthly": 6000,
                "freeTime": 180,  # 3時間無料
                "initialFee": 0,
                "initialTime": 180,
                "details": "最初3時間無料、以降1日100円"
            },
            "openHours": "5:00-25:00",
            "vehicleTypes": ["自転車", "原付"],
            "paymentMethods": ["現金", "回数券", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "metropolitan-plaza",
            "name": "メトロポリタンプラザ駐輪場",
            "address": "東京都豊島区西池袋1-11-1",
            "lat": 35.7299,
            "lng": 139.7089,
            "distance": 100,
            "walkTime": 3,
            "capacity": {
                "total": 200,
                "available": generate_random_availability(200)
            },
            "fees": {
                "hourly": 100,
                "daily": 500,
                "monthly": 7500,
                "freeTime": 60,
                "initialFee": 0,
                "initialTime": 60,
                "details": "最初1時間無料、以降100円/時間"
            },
            "openHours": "6:00-24:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "lumine-parking",
            "name": "ルミネ池袋駐輪場",
            "address": "東京都豊島区西池袋1-11-1",
            "lat": 35.7295,
            "lng": 139.7092,
            "distance": 80,
            "walkTime": 2,
            "capacity": {
                "total": 150,
                "available": generate_random_availability(150)
            },
            "fees": {
                "hourly": 120,
                "daily": 600,
                "monthly": 8000,
                "freeTime": 90,  # 90分無料
                "initialFee": 0,
                "initialTime": 90,
                "details": "最初90分無料、以降120円/時間"
            },
            "openHours": "7:00-23:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "クレジットカード", "電子マネー", "QRコード決済"],
            "lastUpdated": datetime.now().isoformat()
        },
        
        # 池袋南口エリア
        {
            "id": "toshima-ikebukuro-south",
            "name": "豊島区立池袋駅南自転車駐車場",
            "address": "東京都豊島区南池袋2-21-6",
            "lat": 35.7258,
            "lng": 139.7142,
            "distance": 150,
            "walkTime": 3,
            "capacity": {
                "total": 300,
                "available": generate_random_availability(300)
            },
            "fees": {
                "hourly": 0,
                "daily": 100,
                "monthly": 6000,
                "freeTime": 120,  # 2時間無料
                "initialFee": 0,
                "initialTime": 120,
                "details": "最初2時間無料、以降1日100円"
            },
            "openHours": "5:00-25:00",
            "vehicleTypes": ["自転車", "原付"],
            "paymentMethods": ["現金", "回数券", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "tobu-south-parking",
            "name": "東武百貨店南口駐輪場",
            "address": "東京都豊島区南池袋1-28-1",
            "lat": 35.7268,
            "lng": 139.7135,
            "distance": 120,
            "walkTime": 3,
            "capacity": {
                "total": 180,
                "available": generate_random_availability(180)
            },
            "fees": {
                "hourly": 100,
                "daily": 500,
                "monthly": 7500,
                "freeTime": 60,
                "initialFee": 0,
                "initialTime": 60,
                "details": "最初1時間無料、以降100円/時間"
            },
            "openHours": "7:00-23:30",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "クレジットカード", "電子マネー", "QRコード決済"],
            "lastUpdated": datetime.now().isoformat()
        },
        
        # 周辺エリア
        {
            "id": "cycle-times-higashi",
            "name": "サイクルタイムズ東池袋",
            "address": "東京都豊島区東池袋1-12-8",
            "lat": 35.7308,
            "lng": 139.7177,
            "distance": 200,
            "walkTime": 4,
            "capacity": {
                "total": 80,
                "available": generate_random_availability(80)
            },
            "fees": {
                "hourly": 100,
                "daily": 600,
                "monthly": 8000,
                "freeTime": 0,
                "initialFee": 100,
                "initialTime": 60,
                "details": "1時間100円"
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC", "QRコード決済"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "post-office-parking",
            "name": "池袋郵便局前駐輪場",
            "address": "東京都豊島区東池袋3-18-1",
            "lat": 35.7275,
            "lng": 139.7203,
            "distance": 400,
            "walkTime": 6,
            "capacity": {
                "total": 50,
                "available": generate_random_availability(50)
            },
            "fees": {
                "hourly": 80,
                "daily": 400,
                "monthly": 6500,
                "freeTime": 30,
                "initialFee": 0,
                "initialTime": 30,
                "details": "最初30分無料、以降80円/時間"
            },
            "openHours": "6:00-22:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "bic-camera-parking",
            "name": "ビックカメラ池袋本店駐輪場",
            "address": "東京都豊島区東池袋1-41-5",
            "lat": 35.7302,
            "lng": 139.7167,
            "distance": 120,
            "walkTime": 3,
            "capacity": {
                "total": 100,
                "available": generate_random_availability(100)
            },
            "fees": {
                "hourly": 120,
                "daily": 600,
                "monthly": 8500,
                "freeTime": 60,
                "initialFee": 0,
                "initialTime": 60,
                "details": "最初1時間無料（店舗利用者）、以降120円/時間"
            },
            "openHours": "9:00-22:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "クレジットカード", "PayPay", "電子マネー"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "yamada-denki-parking",
            "name": "ヤマダ電機LABI池袋駐輪場",
            "address": "東京都豊島区東池袋1-5-7",
            "lat": 35.7291,
            "lng": 139.7154,
            "distance": 70,
            "walkTime": 2,
            "capacity": {
                "total": 90,
                "available": generate_random_availability(90)
            },
            "fees": {
                "hourly": 100,
                "daily": 500,
                "monthly": 7000,
                "freeTime": 90,
                "initialFee": 0,
                "initialTime": 90,
                "details": "最初90分無料（店舗利用者）、以降100円/時間"
            },
            "openHours": "9:30-22:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "クレジットカード", "PayPay", "電子マネー"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "don-quijote-parking",
            "name": "ドン・キホーテ池袋東口駐輪場",
            "address": "東京都豊島区南池袋1-22-5",
            "lat": 35.7273,
            "lng": 139.7151,
            "distance": 180,
            "walkTime": 4,
            "capacity": {
                "total": 70,
                "available": generate_random_availability(70)
            },
            "fees": {
                "hourly": 100,
                "daily": 500,
                "monthly": 7500,
                "freeTime": 120,  # 2時間無料
                "initialFee": 0,
                "initialTime": 120,
                "details": "最初2時間無料（店舗利用者）、以降100円/時間"
            },
            "openHours": "8:00-翌5:00",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "ikebukuro-six-mata",
            "name": "池袋六ツ又交差点駐輪場",
            "address": "東京都豊島区東池袋4-5-1",
            "lat": 35.7253,
            "lng": 139.7224,
            "distance": 600,
            "walkTime": 8,
            "capacity": {
                "total": 250,
                "available": generate_random_availability(250)
            },
            "fees": {
                "hourly": 0,
                "daily": 150,
                "monthly": 8000,
                "freeTime": 0,
                "initialFee": 150,
                "initialTime": 1440,
                "details": "1日150円（登録制）"
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車", "原付"],
            "paymentMethods": ["現金", "回数券", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        },
        {
            "id": "repark-ikebukuro-east",
            "name": "リパーク池袋東口駐輪場",
            "address": "東京都豊島区東池袋1-2-3",
            "lat": 35.7289,
            "lng": 139.7159,
            "distance": 25,
            "walkTime": 1,
            "capacity": {
                "total": 120,
                "available": generate_random_availability(120)
            },
            "fees": {
                "hourly": 100,
                "daily": 600,
                "monthly": 8000,
                "freeTime": 0,
                "initialFee": 100,
                "initialTime": 60,
                "details": "1時間100円、最大600円/日"
            },
            "openHours": "24時間",
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC", "QRコード決済"],
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
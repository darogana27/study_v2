import json
import os
import boto3
from typing import Dict, List, Any, Tuple
from datetime import datetime
import logging
from decimal import Decimal
# import asyncio
# import aiohttp
from concurrent.futures import ThreadPoolExecutor
import geohash2
import hashlib

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
# stepfunctions = boto3.client('stepfunctions')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'pfc-ParkingSpots-table')
ENABLE_TOKYO_WIDE = os.environ.get('ENABLE_TOKYO_WIDE', 'false').lower() == 'true'
MAX_PARALLEL_WARDS = int(os.environ.get('MAX_PARALLEL_WARDS', '5'))
BATCH_SIZE = int(os.environ.get('BATCH_SIZE', '100'))
ENABLE_GEOHASH = os.environ.get('ENABLE_GEOHASH', 'false').lower() == 'true'

# 東京23区 + 主要市部
TOKYO_AREAS = {
    "23区": [
        "千代田区", "中央区", "港区", "新宿区", "文京区", "台東区", "墨田区", "江東区",
        "品川区", "目黒区", "大田区", "世田谷区", "渋谷区", "中野区", "杉並区", "豊島区",
        "北区", "荒川区", "板橋区", "練馬区", "足立区", "葛飾区", "江戸川区"
    ],
    "多摩地域": [
        "八王子市", "立川市", "武蔵野市", "三鷹市", "青梅市", "府中市", "昭島市", "調布市",
        "町田市", "小金井市", "小平市", "日野市", "東村山市", "国分寺市", "国立市", "福生市",
        "狛江市", "東大和市", "清瀬市", "東久留米市", "武蔵村山市", "多摩市", "稲城市", "羽村市", "あきる野市", "西東京市"
    ]
}

# 主要駅データ（緯度経度付き）
MAJOR_STATIONS = {
    # JR山手線
    "新宿": {"lat": 35.6896, "lng": 139.7006, "ward": "新宿区"},
    "渋谷": {"lat": 35.6580, "lng": 139.7016, "ward": "渋谷区"},
    "池袋": {"lat": 35.7295, "lng": 139.7109, "ward": "豊島区"},
    "品川": {"lat": 35.6284, "lng": 139.7387, "ward": "港区"},
    "東京": {"lat": 35.6812, "lng": 139.7671, "ward": "千代田区"},
    "有楽町": {"lat": 35.6751, "lng": 139.7637, "ward": "千代田区"},
    "新橋": {"lat": 35.6657, "lng": 139.7587, "ward": "港区"},
    "浜松町": {"lat": 35.6555, "lng": 139.7574, "ward": "港区"},
    "田町": {"lat": 35.6455, "lng": 139.7474, "ward": "港区"},
    "高輪ゲートウェイ": {"lat": 35.6366, "lng": 139.7408, "ward": "港区"},
    "大崎": {"lat": 35.6197, "lng": 139.7286, "ward": "品川区"},
    "五反田": {"lat": 35.6258, "lng": 139.7238, "ward": "品川区"},
    "目黒": {"lat": 35.6333, "lng": 139.7156, "ward": "品川区"},
    "恵比寿": {"lat": 35.6465, "lng": 139.7100, "ward": "渋谷区"},
    "原宿": {"lat": 35.6702, "lng": 139.7027, "ward": "渋谷区"},
    "代々木": {"lat": 35.6830, "lng": 139.7021, "ward": "渋谷区"},
    "新大久保": {"lat": 35.7007, "lng": 139.7005, "ward": "新宿区"},
    "高田馬場": {"lat": 35.7125, "lng": 139.7038, "ward": "新宿区"},
    "目白": {"lat": 35.7214, "lng": 139.7060, "ward": "豊島区"},
    "大塚": {"lat": 35.7315, "lng": 139.7285, "ward": "豊島区"},
    "巣鴨": {"lat": 35.7335, "lng": 139.7390, "ward": "豊島区"},
    "駒込": {"lat": 35.7362, "lng": 139.7466, "ward": "豊島区"},
    "田端": {"lat": 35.7378, "lng": 139.7606, "ward": "北区"},
    "西日暮里": {"lat": 35.7323, "lng": 139.7669, "ward": "荒川区"},
    "日暮里": {"lat": 35.7277, "lng": 139.7708, "ward": "荒川区"},
    "鶯谷": {"lat": 35.7214, "lng": 139.7786, "ward": "台東区"},
    "上野": {"lat": 35.7138, "lng": 139.7772, "ward": "台東区"},
    "御徒町": {"lat": 35.7076, "lng": 139.7744, "ward": "台東区"},
    "秋葉原": {"lat": 35.6984, "lng": 139.7734, "ward": "千代田区"},
    "神田": {"lat": 35.6916, "lng": 139.7707, "ward": "千代田区"},
    
    # 主要私鉄駅
    "吉祥寺": {"lat": 35.7032, "lng": 139.5797, "ward": "武蔵野市"},
    "中野": {"lat": 35.7056, "lng": 139.6659, "ward": "中野区"},
    "荻窪": {"lat": 35.7052, "lng": 139.6191, "ward": "杉並区"},
    "立川": {"lat": 35.6988, "lng": 139.4133, "ward": "立川市"},
    "八王子": {"lat": 35.6559, "lng": 139.3389, "ward": "八王子市"},
    "町田": {"lat": 35.5438, "lng": 139.4469, "ward": "町田市"},
    "錦糸町": {"lat": 35.6969, "lng": 139.8147, "ward": "墨田区"},
    "亀戸": {"lat": 35.6970, "lng": 139.8260, "ward": "江東区"},
    "北千住": {"lat": 35.7488, "lng": 139.8049, "ward": "足立区"},
    "金町": {"lat": 35.7675, "lng": 139.8708, "ward": "葛飾区"},
    "船堀": {"lat": 35.6709, "lng": 139.8599, "ward": "江戸川区"},
    "蒲田": {"lat": 35.5617, "lng": 139.7161, "ward": "大田区"},
    "大井町": {"lat": 35.6061, "lng": 139.7330, "ward": "品川区"},
    "自由が丘": {"lat": 35.6081, "lng": 139.6687, "ward": "目黒区"},
    "二子玉川": {"lat": 35.6129, "lng": 139.6277, "ward": "世田谷区"},
    "下北沢": {"lat": 35.6613, "lng": 139.6681, "ward": "世田谷区"},
    "明大前": {"lat": 35.6711, "lng": 139.6369, "ward": "世田谷区"},
    "赤羽": {"lat": 35.7775, "lng": 139.7230, "ward": "北区"},
    "練馬": {"lat": 35.7390, "lng": 139.6532, "ward": "練馬区"},
    "成増": {"lat": 35.7759, "lng": 139.6348, "ward": "板橋区"},
}

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    東京全域駐車場データ収集のメインハンドラー
    """
    try:
        logger.info("Starting Tokyo-wide parking data collection...")
        
        if not ENABLE_TOKYO_WIDE:
            logger.info("Tokyo-wide collection disabled, falling back to Ikebukuro only")
            return collect_ikebukuro_only()
        
        # 並列データ収集実行
        collected_data = collect_tokyo_parking_data()
        
        # DynamoDBに保存
        saved_count = save_to_dynamodb_batch(collected_data)
        
        logger.info(f"Successfully processed {saved_count} parking spots across Tokyo")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully updated {saved_count} parking spots in Tokyo',
                'timestamp': datetime.now().isoformat(),
                'processed_count': saved_count,
                'areas_covered': len(TOKYO_AREAS["23区"]) + len(TOKYO_AREAS["多摩地域"])
            })
        }
        
    except Exception as e:
        logger.error(f"Error in Tokyo parking data collection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to collect Tokyo parking data',
                'message': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }

def collect_tokyo_parking_data() -> List[Dict[str, Any]]:
    """
    東京全域の駐車場データを並列収集
    """
    all_data = []
    
    # 各区・市のデータを並列処理で収集
    with ThreadPoolExecutor(max_workers=MAX_PARALLEL_WARDS) as executor:
        # 23区
        ward_futures = [
            executor.submit(collect_ward_data, ward)
            for ward in TOKYO_AREAS["23区"]
        ]
        
        # 多摩地域（主要市のみ）
        city_futures = [
            executor.submit(collect_city_data, city)
            for city in TOKYO_AREAS["多摩地域"][:10]  # 主要10市のみ
        ]
        
        # 結果収集
        for future in ward_futures + city_futures:
            try:
                data = future.result(timeout=60)
                all_data.extend(data)
            except Exception as e:
                logger.error(f"Failed to collect data from area: {str(e)}")
                continue
    
    logger.info(f"Generated data for {len(all_data)} parking spots across Tokyo")
    return all_data

def collect_ward_data(ward: str) -> List[Dict[str, Any]]:
    """
    指定区の駐車場データを収集
    """
    data = []
    
    # 区内の主要駅を特定
    ward_stations = [
        station for station, info in MAJOR_STATIONS.items()
        if info["ward"] == ward
    ]
    
    # 駅ごとに駐車場データを生成
    for station in ward_stations:
        station_data = generate_station_parking_data(station, ward)
        data.extend(station_data)
    
    # 区の一般的な駐車場も追加
    general_data = generate_ward_general_parking(ward)
    data.extend(general_data)
    
    logger.info(f"Collected {len(data)} parking spots for {ward}")
    return data

def collect_city_data(city: str) -> List[Dict[str, Any]]:
    """
    指定市の駐車場データを収集
    """
    data = []
    
    # 市内の主要駅を特定
    city_stations = [
        station for station, info in MAJOR_STATIONS.items()
        if info["ward"] == city
    ]
    
    # 駅ごとに駐車場データを生成
    for station in city_stations:
        station_data = generate_station_parking_data(station, city)
        data.extend(station_data)
    
    logger.info(f"Collected {len(data)} parking spots for {city}")
    return data

def generate_station_parking_data(station: str, area: str) -> List[Dict[str, Any]]:
    """
    駅周辺の駐車場データを生成
    """
    base_info = MAJOR_STATIONS[station]
    data = []
    
    # 駅の規模に応じて駐車場数を調整
    major_stations = ["新宿", "渋谷", "池袋", "東京", "品川", "上野", "立川", "吉祥寺"]
    spot_count = 15 if station in major_stations else 8
    
    for i in range(spot_count):
        # 駅周辺にランダム配置
        lat_offset = (hash(f"{station}_{i}_lat") % 2000 - 1000) / 100000  # ±0.01度
        lng_offset = (hash(f"{station}_{i}_lng") % 2000 - 1000) / 100000
        
        lat = base_info["lat"] + lat_offset
        lng = base_info["lng"] + lng_offset
        
        # GeoHashを生成
        geo_hash = geohash2.encode(lat, lng, precision=7) if ENABLE_GEOHASH else ""
        
        parking_spot = {
            "id": f"{area.replace('区', '').replace('市', '')}-{station}-{i+1:02d}",
            "name": f"{station}駅{get_direction(i)}駐輪場",
            "address": f"東京都{area}{get_mock_address(station, i)}",
            "lat": lat,
            "lng": lng,
            "ward": area,
            "station": station,
            "geoHash": geo_hash,
            "distance": generate_distance(i),
            "walkTime": max(1, generate_distance(i) // 80),
            "capacity": {
                "total": generate_capacity(),
                "available": None  # 後で設定
            },
            "fees": generate_fees(station in major_stations),
            "openHours": generate_hours(),
            "vehicleTypes": generate_vehicle_types(),
            "paymentMethods": generate_payment_methods(station in major_stations),
            "lastUpdated": datetime.now().isoformat()
        }
        
        # 空き状況を生成
        parking_spot["capacity"]["available"] = generate_random_availability(
            parking_spot["capacity"]["total"]
        )
        
        data.append(parking_spot)
    
    return data

def generate_ward_general_parking(ward: str) -> List[Dict[str, Any]]:
    """
    区の一般的な駐車場を生成（駅以外）
    """
    data = []
    
    # 区の中心座標を推定（主要駅の平均）
    ward_stations = [
        info for station, info in MAJOR_STATIONS.items()
        if info["ward"] == ward
    ]
    
    if not ward_stations:
        return data
        
    avg_lat = sum(s["lat"] for s in ward_stations) / len(ward_stations)
    avg_lng = sum(s["lng"] for s in ward_stations) / len(ward_stations)
    
    # 一般駐車場を5-10箇所生成
    spot_count = 5 + (hash(ward) % 6)
    
    for i in range(spot_count):
        lat_offset = (hash(f"{ward}_general_{i}_lat") % 4000 - 2000) / 100000
        lng_offset = (hash(f"{ward}_general_{i}_lng") % 4000 - 2000) / 100000
        
        lat = avg_lat + lat_offset
        lng = avg_lng + lng_offset
        
        geo_hash = geohash2.encode(lat, lng, precision=7) if ENABLE_GEOHASH else ""
        
        parking_spot = {
            "id": f"{ward.replace('区', '').replace('市', '')}-general-{i+1:02d}",
            "name": f"{ward}公共駐輪場{i+1}",
            "address": f"東京都{ward}{get_mock_general_address(i)}",
            "lat": lat,
            "lng": lng,
            "ward": ward,
            "station": "一般",
            "geoHash": geo_hash,
            "distance": 200 + (i * 100),
            "walkTime": 3 + i,
            "capacity": {
                "total": generate_capacity(),
                "available": None
            },
            "fees": generate_fees(False),
            "openHours": generate_hours(),
            "vehicleTypes": ["自転車"],
            "paymentMethods": ["現金", "交通系IC"],
            "lastUpdated": datetime.now().isoformat()
        }
        
        parking_spot["capacity"]["available"] = generate_random_availability(
            parking_spot["capacity"]["total"]
        )
        
        data.append(parking_spot)
    
    return data

def get_direction(index: int) -> str:
    """方角を取得"""
    directions = ["東口", "西口", "南口", "北口", "中央", "地下", "高架下"]
    return directions[index % len(directions)]

def get_mock_address(station: str, index: int) -> str:
    """模擬住所を生成"""
    numbers = [
        f"{1 + index}-{1 + (index % 10)}-{1 + (index % 5)}",
        f"{2 + index}-{10 + index}-{1 + (index % 8)}",
        f"{3 + (index % 5)}-{5 + index}-{1 + (index % 12)}"
    ]
    return numbers[index % len(numbers)]

def get_mock_general_address(index: int) -> str:
    """一般駐車場の模擬住所を生成"""
    return f"{1 + index}-{1 + (index % 20)}-{1 + (index % 15)}"

def generate_distance(index: int) -> int:
    """駅からの距離を生成"""
    base_distances = [30, 60, 100, 150, 200, 300, 400, 500]
    return base_distances[index % len(base_distances)]

def generate_capacity() -> int:
    """駐車場容量を生成"""
    capacities = [50, 80, 100, 120, 150, 200, 300, 500]
    return capacities[hash(datetime.now().isoformat()) % len(capacities)]

def generate_fees(is_major_station: bool) -> Dict[str, Any]:
    """料金体系を生成"""
    if is_major_station:
        fee_patterns = [
            {
                "hourly": 100, "daily": 600, "monthly": 8000,
                "freeTime": 120, "initialFee": 0, "initialTime": 120,
                "details": "最初2時間無料、以降100円/時間"
            },
            {
                "hourly": 120, "daily": 500, "monthly": 7500,
                "freeTime": 60, "initialFee": 0, "initialTime": 60,
                "details": "最初1時間無料、以降120円/時間"
            }
        ]
    else:
        fee_patterns = [
            {
                "hourly": 80, "daily": 400, "monthly": 6000,
                "freeTime": 60, "initialFee": 0, "initialTime": 60,
                "details": "最初1時間無料、以降80円/時間"
            },
            {
                "hourly": 0, "daily": 150, "monthly": 5000,
                "freeTime": 180, "initialFee": 0, "initialTime": 180,
                "details": "最初3時間無料、以降1日150円"
            }
        ]
    
    return fee_patterns[hash(datetime.now().minute) % len(fee_patterns)]

def generate_hours() -> str:
    """営業時間を生成"""
    hour_patterns = ["24時間", "5:00-25:00", "6:00-24:00", "7:00-23:00"]
    return hour_patterns[hash(datetime.now().second) % len(hour_patterns)]

def generate_vehicle_types() -> List[str]:
    """対応車両タイプを生成"""
    type_patterns = [
        ["自転車"],
        ["自転車", "原付"],
        ["自転車", "電動自転車"],
        ["自転車", "原付", "電動自転車"]
    ]
    return type_patterns[hash(datetime.now().microsecond) % len(type_patterns)]

def generate_payment_methods(is_major_station: bool) -> List[str]:
    """支払い方法を生成"""
    if is_major_station:
        return ["現金", "交通系IC", "クレジットカード", "QRコード決済", "電子マネー"]
    else:
        return ["現金", "交通系IC"]

def generate_random_availability(total: int) -> int:
    """リアルタイム風の空き状況を生成"""
    import random
    
    current_hour = datetime.now().hour
    
    # 時間帯別の利用率
    if 7 <= current_hour <= 9:
        usage_rate = random.uniform(0.7, 0.9)
    elif 17 <= current_hour <= 19:
        usage_rate = random.uniform(0.6, 0.8)
    elif 12 <= current_hour <= 14:
        usage_rate = random.uniform(0.4, 0.6)
    elif 20 <= current_hour <= 23:
        usage_rate = random.uniform(0.3, 0.5)
    else:
        usage_rate = random.uniform(0.2, 0.4)
    
    used_spots = int(total * usage_rate)
    available = total - used_spots
    
    return max(0, available)

def collect_ikebukuro_only() -> Dict[str, Any]:
    """
    池袋エリアのみの従来処理（フォールバック）
    """
    try:
        # 既存の池袋限定データ収集ロジック
        ikebukuro_data = generate_station_parking_data("池袋", "豊島区")
        saved_count = save_to_dynamodb_batch(ikebukuro_data)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully updated {saved_count} parking spots in Ikebukuro',
                'timestamp': datetime.now().isoformat(),
                'processed_count': saved_count,
                'areas_covered': 1
            })
        }
    except Exception as e:
        logger.error(f"Error in Ikebukuro fallback: {str(e)}")
        raise

def save_to_dynamodb_batch(parking_data: List[Dict[str, Any]]) -> int:
    """
    DynamoDBにバッチでデータを保存
    """
    table = dynamodb.Table(TABLE_NAME)
    saved_count = 0
    
    try:
        # バッチサイズごとに分割して処理
        for i in range(0, len(parking_data), BATCH_SIZE):
            batch = parking_data[i:i + BATCH_SIZE]
            
            with table.batch_writer() as writer:
                for spot in batch:
                    # DynamoDB用にDecimal変換
                    spot_data = convert_floats_to_decimal(spot)
                    writer.put_item(Item=spot_data)
                    saved_count += 1
            
            logger.info(f"Saved batch {i//BATCH_SIZE + 1}, total: {saved_count}")
                
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
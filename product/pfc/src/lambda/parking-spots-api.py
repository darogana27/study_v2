import json
import os
import boto3
from typing import Dict, List, Any, Optional
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'pfc-ParkingSpots-table')
ENABLE_TOKYO_WIDE = os.environ.get('ENABLE_TOKYO_WIDE', 'true').lower() == 'true'

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    駐輪場データAPI のメインハンドラー - 東京全域地理検索対応
    """
    try:
        # クエリパラメータを取得
        query_params = event.get('queryStringParameters') or {}
        
        # 地理検索パラメータ
        ward = query_params.get('ward')
        station = query_params.get('station')
        area = query_params.get('area')
        lat = query_params.get('lat')
        lng = query_params.get('lng')
        radius = int(query_params.get('radius', 1000))  # デフォルト1km
        limit = int(query_params.get('limit', 50))  # デフォルト50件
        
        # 東京全域モードが有効かつ地理検索パラメータがある場合
        if ENABLE_TOKYO_WIDE and (ward or station or area):
            parking_data = get_parking_data_tokyo_wide(ward, station, area, limit)
        elif lat and lng:
            # 座標ベースの近傍検索
            parking_data = get_parking_data_by_location(float(lat), float(lng), radius, limit)
        else:
            # 従来の全件取得
            parking_data = get_parking_data()
        
        # フロントエンド用のフォーマットに変換
        formatted_data = format_for_frontend(parking_data)
        
        return create_response(200, formatted_data)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return create_response(500, {
            'error': 'データの取得に失敗しました',
            'message': str(e)
        })


def get_parking_data_tokyo_wide(ward: Optional[str] = None, station: Optional[str] = None, area: Optional[str] = None, limit: int = 50) -> List[Dict[str, Any]]:
    """
    東京全域対応：GSIを使用した効率的な地理検索
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        items = []
        
        if ward:
            # WardIndexを使用した区での検索
            response = table.query(
                IndexName='WardIndex',
                KeyConditionExpression='ward = :ward',
                ExpressionAttributeValues={':ward': ward},
                Limit=limit
            )
            items = response.get('Items', [])
        elif station:
            # StationIndexを使用した駅での検索
            response = table.query(
                IndexName='StationIndex',
                KeyConditionExpression='station = :station',
                ExpressionAttributeValues={':station': station},
                Limit=limit
            )
            items = response.get('Items', [])
        elif area:
            # エリア指定による検索（主要駅マッピング）
            station_mapping = {
                'shinjuku': '新宿', 'shibuya': '渋谷', 'ikebukuro': '池袋',
                'tokyo': '東京', 'shinagawa': '品川', 'ueno': '上野',
                'kichijoji': '吉祥寺', 'tachikawa': '立川', 'machida': '町田'
            }
            station_name = station_mapping.get(area, area)
            response = table.query(
                IndexName='StationIndex',
                KeyConditionExpression='station = :station',
                ExpressionAttributeValues={':station': station_name},
                Limit=limit
            )
            items = response.get('Items', [])
        else:
            # 全体スキャン（制限付き）
            response = table.scan(Limit=limit)
            items = response.get('Items', [])
        
        # Decimalを通常の数値に変換
        return [convert_decimal(item) for item in items]
        
    except Exception as e:
        print(f"Tokyo-wide DynamoDB Error: {str(e)}")
        # フォールバック：従来の方法
        return get_parking_data()


def get_parking_data_by_location(lat: float, lng: float, radius: int = 1000, limit: int = 50) -> List[Dict[str, Any]]:
    """
    座標ベースの近傍検索（GeoHashを使用）
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        # 簡易的な近傍検索（実装時はGeoHashライブラリを使用）
        # ここでは全データを取得してアプリケーション側でフィルタリング
        response = table.scan(Limit=100)  # 制限付きスキャン
        items = response.get('Items', [])
        
        # 距離計算とフィルタリング
        nearby_items = []
        for item in items:
            item_lat = float(item.get('lat', 0))
            item_lng = float(item.get('lng', 0))
            
            # 簡易距離計算（Haversine式の簡略版）
            distance = calculate_distance(lat, lng, item_lat, item_lng)
            
            if distance <= radius:
                item['calculated_distance'] = distance
                nearby_items.append(item)
        
        # 距離順でソート
        nearby_items.sort(key=lambda x: x.get('calculated_distance', 999999))
        
        # Decimalを通常の数値に変換
        return [convert_decimal(item) for item in nearby_items[:limit]]
        
    except Exception as e:
        print(f"Location-based search error: {str(e)}")
        return []


def calculate_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """
    2点間の距離を計算（メートル単位）
    """
    import math
    
    # 地球の半径（km）
    R = 6371.0
    
    # 度をラジアンに変換
    lat1_rad = math.radians(lat1)
    lng1_rad = math.radians(lng1)
    lat2_rad = math.radians(lat2)
    lng2_rad = math.radians(lng2)
    
    # 差分
    dlat = lat2_rad - lat1_rad
    dlng = lng2_rad - lng1_rad
    
    # Haversine式
    a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    # km → m に変換
    distance = R * c * 1000
    
    return distance


def get_parking_data() -> List[Dict[str, Any]]:
    """
    DynamoDBから駐輪場データを取得（従来版）
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


def format_for_frontend(parking_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    フロントエンド用にデータをフォーマット（新旧スキーマ対応）
    """
    formatted = []
    
    for spot in parking_data:
        try:
            # 容量データの取得（新旧スキーマ対応）
            if 'capacity' in spot and isinstance(spot['capacity'], dict):
                total = spot['capacity']['total']
                available = spot['capacity']['available']
            else:
                total = spot.get('total', spot.get('capacity', 0))
                available = spot.get('available', spot.get('available_spots', 0))
            
            occupancy_rate = int(((total - available) / total) * 100) if total > 0 else 0
            
            # 料金データの取得（新旧スキーマ対応）
            if 'fees' in spot and isinstance(spot['fees'], dict):
                daily_fee = spot['fees'].get('daily', 0)
                fee_details = spot['fees'].get('details', f"1日{daily_fee}円")
                free_time = spot['fees'].get('freeTime', 0)
            else:
                daily_fee = spot.get('daily_fee', spot.get('fees', 0))
                fee_details = f"1日{daily_fee}円"
                free_time = spot.get('free_time', 0)
            
            # 無料時間がある場合の表示
            free_badge = ""
            if free_time > 0:
                if free_time >= 60:
                    free_badge = f"{free_time//60}時間無料"
                else:
                    free_badge = f"{free_time}分無料"
            
            price_display = f"1日{daily_fee}円"
            
            # 座標データの取得（新旧スキーマ対応）
            if 'coordinates' in spot and isinstance(spot['coordinates'], dict):
                lat = spot['coordinates'].get('lat', 0)
                lng = spot['coordinates'].get('lng', 0)
            else:
                lat = spot.get('lat', 0)
                lng = spot.get('lng', 0)
            
            # 距離・時間データの取得
            distance = spot.get('distance', spot.get('calculated_distance', 0))
            walk_time = spot.get('walkTime', spot.get('walk_time', 0))
            
            # 車種データの取得（新旧スキーマ対応）
            vehicle_types = spot.get('vehicleTypes', spot.get('bikeTypes', []))
            if isinstance(vehicle_types, str):
                vehicle_types = [vehicle_types]
            
            formatted_spot = {
                'id': spot['id'],
                'name': spot['name'],
                'address': spot.get('address', ''),
                'lat': lat,
                'lng': lng,
                'coordinates': {'lat': lat, 'lng': lng},  # 統一フォーマット
                'distance': f"{int(distance)}m",
                'walkTime': f"徒歩{walk_time}分",
                'price': price_display,
                'priceDetails': fee_details,
                'freeBadge': free_badge,
                'hours': spot.get('openHours', spot.get('hours', '24時間')),
                'vehicleTypes': ', '.join(vehicle_types),
                'paymentMethods': ', '.join(spot.get('paymentMethods', ['現金'])),
                'paymentMethodsList': spot.get('paymentMethods', ['現金']),
                'occupancyRate': occupancy_rate,
                'available': available,
                'total': total,
                'availabilityText': f"空き {available}台 / 全{total}台",
                'availabilityShort': f"空き{available}台",
                'lastUpdated': spot.get('lastUpdated', ''),
                # 東京全域対応のメタデータ
                'ward': spot.get('ward', ''),
                'station': spot.get('station', ''),
                'area': spot.get('area', ''),
                'geoHash': spot.get('geoHash', '')
            }
            
            formatted.append(formatted_spot)
            
        except Exception as e:
            print(f"Error formatting spot {spot.get('id', 'unknown')}: {str(e)}")
            continue
    
    # 距離順でソート
    try:
        formatted.sort(key=lambda x: int(x['distance'].replace('m', '')))
    except (ValueError, AttributeError):
        # ソートに失敗した場合はそのまま返す
        pass
    
    return formatted


def create_response(status_code: int, body: Any) -> Dict[str, Any]:
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
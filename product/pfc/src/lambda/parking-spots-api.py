import json
import os
import boto3
from typing import Dict, List, Any
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'pfc-ParkingSpots-table')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    駐輪場データAPI のメインハンドラー
    """
    try:
        # DynamoDBから駐輪場データを取得
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


def format_for_frontend(parking_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    フロントエンド用にデータをフォーマット
    """
    formatted = []
    
    for spot in parking_data:
        try:
            total = spot['capacity']['total']
            available = spot['capacity']['available']
            occupancy_rate = int(((total - available) / total) * 100) if total > 0 else 0
            
            formatted_spot = {
                'id': spot['id'],
                'name': spot['name'],
                'address': spot['address'],
                'distance': f"{spot['distance']}m",
                'walkTime': f"徒歩{spot['walkTime']}分",
                'price': f"1日{spot['fees']['daily']}円",
                'hours': spot['openHours'],
                'vehicleTypes': ', '.join(spot['vehicleTypes']),
                'occupancyRate': occupancy_rate,
                'available': available,
                'total': total,
                'lastUpdated': spot.get('lastUpdated', '')
            }
            
            formatted.append(formatted_spot)
            
        except Exception as e:
            print(f"Error formatting spot {spot.get('id', 'unknown')}: {str(e)}")
            continue
    
    # 距離順でソート
    formatted.sort(key=lambda x: int(x['distance'].replace('m', '')))
    
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
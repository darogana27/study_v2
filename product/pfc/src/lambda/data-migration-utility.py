#!/usr/bin/env python3
"""
PFC DynamoDB Data Migration Utility
東京全域対応：古いスキーマから新しいスキーマへのデータ移行

Usage:
    python data-migration-utility.py --action=migrate
    python data-migration-utility.py --action=validate
    python data-migration-utility.py --action=cleanup
"""

import json
import os
import boto3
from typing import Dict, List, Any, Optional
from datetime import datetime
from decimal import Decimal
import argparse
import logging

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'pfc-ParkingSpots-table')

def convert_decimal(obj: Any) -> Any:
    """DynamoDBのDecimal型を通常の数値型に変換"""
    if isinstance(obj, list):
        return [convert_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_decimal(value) for key, value in obj.items()}
    elif isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj

def scan_all_items() -> List[Dict[str, Any]]:
    """DynamoDBから全アイテムをスキャン"""
    table = dynamodb.Table(TABLE_NAME)
    items = []
    
    try:
        response = table.scan()
        items.extend(response.get('Items', []))
        
        # ページネーション処理
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response.get('Items', []))
        
        logger.info(f"Scanned {len(items)} items from DynamoDB")
        return [convert_decimal(item) for item in items]
        
    except Exception as e:
        logger.error(f"Error scanning DynamoDB: {str(e)}")
        return []

def is_old_schema(item: Dict[str, Any]) -> bool:
    """アイテムが古いスキーマかどうかを判定"""
    old_schema_indicators = [
        # 容量データが直接格納されている
        'total' in item and 'available' in item and 'capacity' not in item,
        # 料金データが直接格納されている
        'daily_fee' in item and 'fees' not in item,
        # 古い車種フィールド名
        'bikeTypes' in item and 'vehicleTypes' not in item,
        # ward, station, geoHashフィールドがない
        'ward' not in item or 'station' not in item
    ]
    
    return any(old_schema_indicators)

def migrate_item_schema(item: Dict[str, Any]) -> Dict[str, Any]:
    """アイテムを新しいスキーマに移行"""
    migrated_item = item.copy()
    
    # 容量データの移行
    if 'total' in item and 'available' in item and 'capacity' not in item:
        migrated_item['capacity'] = {
            'total': item['total'],
            'available': item['available']
        }
        # 古いフィールドを削除
        migrated_item.pop('total', None)
        migrated_item.pop('available', None)
    
    # 料金データの移行
    if 'daily_fee' in item and 'fees' not in item:
        migrated_item['fees'] = {
            'daily': item.get('daily_fee', 0),
            'hourly': item.get('hourly_fee', 0),
            'monthly': item.get('monthly_fee', 0),
            'details': f"1日{item.get('daily_fee', 0)}円"
        }
        # 古いフィールドを削除
        migrated_item.pop('daily_fee', None)
        migrated_item.pop('hourly_fee', None)
        migrated_item.pop('monthly_fee', None)
    
    # 車種データの移行
    if 'bikeTypes' in item and 'vehicleTypes' not in item:
        migrated_item['vehicleTypes'] = item['bikeTypes']
        migrated_item.pop('bikeTypes', None)
    
    # 座標データの統一（coordinatesオブジェクトがある場合は展開）
    if 'coordinates' in item and isinstance(item['coordinates'], dict):
        migrated_item['lat'] = item['coordinates'].get('lat', 0)
        migrated_item['lng'] = item['coordinates'].get('lng', 0)
    
    # 新しいメタデータフィールドの追加（存在しない場合）
    if 'ward' not in migrated_item:
        # 住所から区を推定（簡易実装）
        address = migrated_item.get('address', '')
        if '豊島区' in address:
            migrated_item['ward'] = '豊島区'
            migrated_item['station'] = '池袋'
        else:
            migrated_item['ward'] = '不明'
            migrated_item['station'] = '不明'
    
    if 'geoHash' not in migrated_item:
        migrated_item['geoHash'] = ''
    
    # 最終更新時刻を追加
    migrated_item['lastUpdated'] = datetime.now().isoformat()
    migrated_item['migrated'] = True
    
    return migrated_item

def validate_schema(item: Dict[str, Any]) -> List[str]:
    """新しいスキーマの検証"""
    errors = []
    
    # 必須フィールドの確認
    required_fields = ['id', 'name', 'lat', 'lng', 'ward', 'station']
    for field in required_fields:
        if field not in item:
            errors.append(f"Missing required field: {field}")
    
    # 容量データの構造確認
    if 'capacity' in item:
        if not isinstance(item['capacity'], dict):
            errors.append("capacity should be an object")
        else:
            if 'total' not in item['capacity']:
                errors.append("capacity.total is missing")
            if 'available' not in item['capacity']:
                errors.append("capacity.available is missing")
    else:
        errors.append("capacity field is missing")
    
    # 料金データの構造確認
    if 'fees' in item:
        if not isinstance(item['fees'], dict):
            errors.append("fees should be an object")
        else:
            if 'daily' not in item['fees']:
                errors.append("fees.daily is missing")
    else:
        errors.append("fees field is missing")
    
    return errors

def migrate_data():
    """データ移行の実行"""
    logger.info("Starting data migration...")
    
    # 全アイテムを取得
    items = scan_all_items()
    
    if not items:
        logger.warning("No items found to migrate")
        return
    
    # 古いスキーマのアイテムを特定
    old_items = [item for item in items if is_old_schema(item)]
    logger.info(f"Found {len(old_items)} items with old schema")
    
    if not old_items:
        logger.info("No migration needed - all items are already using new schema")
        return
    
    # バッチ書き込みで移行
    table = dynamodb.Table(TABLE_NAME)
    
    with table.batch_writer() as batch:
        for item in old_items:
            migrated_item = migrate_item_schema(item)
            
            # 検証
            errors = validate_schema(migrated_item)
            if errors:
                logger.warning(f"Validation errors for item {item.get('id', 'unknown')}: {errors}")
                continue
            
            # DynamoDB用にDecimalに変換
            for key, value in migrated_item.items():
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    migrated_item[key] = Decimal(str(value))
            
            batch.put_item(Item=migrated_item)
            logger.info(f"Migrated item: {migrated_item['id']}")
    
    logger.info(f"Migration completed: {len(old_items)} items migrated")

def validate_data():
    """データ検証の実行"""
    logger.info("Starting data validation...")
    
    items = scan_all_items()
    total_errors = 0
    
    for item in items:
        errors = validate_schema(item)
        if errors:
            logger.error(f"Validation errors for item {item.get('id', 'unknown')}: {errors}")
            total_errors += len(errors)
    
    if total_errors == 0:
        logger.info("✅ All items passed validation")
    else:
        logger.warning(f"❌ Found {total_errors} validation errors across items")

def cleanup_old_fields():
    """古いフィールドのクリーンアップ（注意深く実行）"""
    logger.info("Starting cleanup of old fields...")
    
    items = scan_all_items()
    
    # クリーンアップ対象フィールド
    fields_to_remove = ['total', 'available', 'daily_fee', 'hourly_fee', 'monthly_fee', 'bikeTypes']
    
    table = dynamodb.Table(TABLE_NAME)
    cleaned_count = 0
    
    for item in items:
        has_old_fields = any(field in item for field in fields_to_remove)
        
        if has_old_fields:
            # 古いフィールドを削除
            cleaned_item = {k: v for k, v in item.items() if k not in fields_to_remove}
            
            # DynamoDB用にDecimalに変換
            for key, value in cleaned_item.items():
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    cleaned_item[key] = Decimal(str(value))
            
            table.put_item(Item=cleaned_item)
            cleaned_count += 1
            logger.info(f"Cleaned up item: {item['id']}")
    
    logger.info(f"Cleanup completed: {cleaned_count} items cleaned")

def main():
    parser = argparse.ArgumentParser(description='PFC DynamoDB Data Migration Utility')
    parser.add_argument('--action', choices=['migrate', 'validate', 'cleanup'], 
                       required=True, help='Action to perform')
    
    args = parser.parse_args()
    
    logger.info(f"Starting action: {args.action}")
    logger.info(f"Target table: {TABLE_NAME}")
    
    if args.action == 'migrate':
        migrate_data()
    elif args.action == 'validate':
        validate_data()
    elif args.action == 'cleanup':
        logger.warning("⚠️  Cleanup will permanently delete old fields. Are you sure?")
        confirm = input("Type 'yes' to continue: ")
        if confirm.lower() == 'yes':
            cleanup_old_fields()
        else:
            logger.info("Cleanup cancelled")

if __name__ == '__main__':
    main()
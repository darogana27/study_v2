// Lambda関数: チャット応答処理
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

// チャットボットのメインハンドラー
exports.handler = async (event) => {
    const body = JSON.parse(event.body);
    const message = body.message.toLowerCase();
    
    try {
        // DynamoDBから駐輪場データを取得
        const parkingData = await getParkingData();
        
        // メッセージに応じた応答を生成
        const response = await generateResponse(message, parkingData);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify(response)
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ 
                error: 'エラーが発生しました',
                message: 'しばらく時間をおいて再度お試しください' 
            })
        };
    }
};

// DynamoDBから駐輪場データを取得
async function getParkingData() {
    const params = {
        TableName: 'ParkingLots',
        ProjectionExpression: '#n, #id, address, coordinates, capacity, fees, bikeTypes, openHours, distance, walkTime',
        ExpressionAttributeNames: {
            '#n': 'name',
            '#id': 'id'
        }
    };
    
    const result = await dynamodb.scan(params).promise();
    return result.Items;
}

// チャット応答を生成
async function generateResponse(message, parkingData) {
    // キーワードマッチング
    if (message.includes('空') || message.includes('空き') || message.includes('available')) {
        return getAvailableParkingResponse(parkingData);
    }
    
    if (message.includes('近') || message.includes('最寄') || message.includes('nearest')) {
        return getNearestParkingResponse(parkingData);
    }
    
    if (message.includes('安') || message.includes('cheap') || message.includes('料金')) {
        return getCheapestParkingResponse(parkingData);
    }
    
    if (message.includes('24時間') || message.includes('深夜') || message.includes('夜')) {
        return get24HourParkingResponse(parkingData);
    }
    
    // デフォルト応答
    return {
        type: 'list',
        message: '池袋エリアの駐輪場情報です。どのような条件でお探しですか？',
        suggestions: ['空いている駐輪場', '一番近い駐輪場', '24時間営業', '料金が安い順'],
        parkingLots: parkingData.slice(0, 3)
    };
}

// 空き駐輪場の応答
function getAvailableParkingResponse(parkingData) {
    const available = parkingData
        .filter(p => p.capacity.available > 10)
        .sort((a, b) => b.capacity.available - a.capacity.available);
    
    return {
        type: 'available',
        message: `現在、${available.length}件の駐輪場に空きがあります！`,
        parkingLots: available.slice(0, 3),
        totalFound: available.length
    };
}

// 最寄り駐輪場の応答
function getNearestParkingResponse(parkingData) {
    const nearest = parkingData
        .sort((a, b) => a.distance - b.distance);
    
    return {
        type: 'nearest',
        message: '池袋駅から近い順に表示します',
        parkingLots: nearest.slice(0, 3),
        totalFound: nearest.length
    };
}

// 安い駐輪場の応答
function getCheapestParkingResponse(parkingData) {
    const cheapest = parkingData
        .sort((a, b) => a.fees.daily - b.fees.daily);
    
    return {
        type: 'cheapest',
        message: '料金が安い順に表示します（1日料金）',
        parkingLots: cheapest.slice(0, 3),
        totalFound: cheapest.length
    };
}

// 24時間営業の応答
function get24HourParkingResponse(parkingData) {
    const allDay = parkingData
        .filter(p => p.openHours.includes('24時間'));
    
    return {
        type: '24hours',
        message: `24時間営業の駐輪場が${allDay.length}件見つかりました`,
        parkingLots: allDay,
        totalFound: allDay.length
    };
}
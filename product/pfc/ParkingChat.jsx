import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import './ParkingChat.css';

const API_ENDPOINT = 'https://your-api-gateway-url.amazonaws.com/prod/chat';

const ParkingChat = () => {
  const [messages, setMessages] = useState([
    {
      type: 'bot',
      text: 'こんにちは！池袋エリアの駐輪場をお探しですか？',
      timestamp: new Date()
    }
  ]);
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedParking, setSelectedParking] = useState(null);
  const [parkingLots, setParkingLots] = useState([]);
  const messagesEndRef = useRef(null);

  // 自動スクロール
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // メッセージ送信
  const sendMessage = async () => {
    if (!inputText.trim()) return;

    const userMessage = {
      type: 'user',
      text: inputText,
      timestamp: new Date()
    };

    setMessages([...messages, userMessage]);
    setInputText('');
    setIsLoading(true);

    try {
      const response = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message: inputText })
      });

      const data = await response.json();
      
      const botMessage = {
        type: 'bot',
        text: data.message,
        parkingLots: data.parkingLots,
        suggestions: data.suggestions,
        timestamp: new Date()
      };

      setMessages(prev => [...prev, botMessage]);
      if (data.parkingLots) {
        setParkingLots(data.parkingLots);
      }
    } catch (error) {
      console.error('Error:', error);
      const errorMessage = {
        type: 'bot',
        text: 'エラーが発生しました。もう一度お試しください。',
        timestamp: new Date()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  // クイック返信ボタン
  const quickReplies = [
    '空いている駐輪場',
    '一番近い駐輪場',
    '24時間営業',
    '料金が安い順'
  ];

  return (
    <div className="parking-chat-container">
      <div className="chat-section">
        <div className="chat-header">
          <h2>🚲 池袋駐輪場アシスタント</h2>
        </div>
        
        <div className="messages-container">
          {messages.map((msg, index) => (
            <div key={index} className={`message ${msg.type}`}>
              <div className="message-content">
                <p>{msg.text}</p>
                
                {msg.parkingLots && (
                  <div className="parking-list">
                    {msg.parkingLots.map((lot) => (
                      <div 
                        key={lot.id} 
                        className="parking-card"
                        onClick={() => setSelectedParking(lot)}
                      >
                        <h4>{lot.name}</h4>
                        <div className="parking-info">
                          <span className="available">
                            空き: {lot.capacity.available}/{lot.capacity.total}台
                          </span>
                          <span className="distance">
                            徒歩{lot.walkTime}分 ({lot.distance}m)
                          </span>
                        </div>
                        <div className="parking-details">
                          <span>💰 {lot.fees.daily}円/日</span>
                          <span>🕐 {lot.openHours}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
                
                {msg.suggestions && (
                  <div className="suggestions">
                    {msg.suggestions.map((suggestion, idx) => (
                      <button
                        key={idx}
                        className="suggestion-btn"
                        onClick={() => setInputText(suggestion)}
                      >
                        {suggestion}
                      </button>
                    ))}
                  </div>
                )}
              </div>
              <span className="timestamp">
                {msg.timestamp.toLocaleTimeString()}
              </span>
            </div>
          ))}
          {isLoading && (
            <div className="message bot loading">
              <div className="typing-indicator">
                <span></span>
                <span></span>
                <span></span>
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>
        
        <div className="input-section">
          <div className="quick-replies">
            {quickReplies.map((reply, index) => (
              <button
                key={index}
                className="quick-reply-btn"
                onClick={() => setInputText(reply)}
              >
                {reply}
              </button>
            ))}
          </div>
          <div className="input-container">
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
              placeholder="メッセージを入力..."
              className="message-input"
            />
            <button 
              onClick={sendMessage} 
              disabled={isLoading}
              className="send-btn"
            >
              送信
            </button>
          </div>
        </div>
      </div>
      
      <div className="map-section">
        <MapContainer 
          center={[35.7295, 139.7109]} 
          zoom={15} 
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          />
          {parkingLots.map((lot) => (
            <Marker 
              key={lot.id}
              position={[lot.coordinates.lat, lot.coordinates.lng]}
              eventHandlers={{
                click: () => setSelectedParking(lot)
              }}
            >
              <Popup>
                <div>
                  <h4>{lot.name}</h4>
                  <p>空き: {lot.capacity.available}台</p>
                  <p>料金: {lot.fees.daily}円/日</p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
      
      {selectedParking && (
        <div className="parking-detail-modal">
          <div className="modal-content">
            <button 
              className="close-btn"
              onClick={() => setSelectedParking(null)}
            >
              ×
            </button>
            <h3>{selectedParking.name}</h3>
            <p className="address">{selectedParking.address}</p>
            <div className="detail-grid">
              <div>
                <strong>空き状況:</strong> {selectedParking.capacity.available}/{selectedParking.capacity.total}台
              </div>
              <div>
                <strong>営業時間:</strong> {selectedParking.openHours}
              </div>
              <div>
                <strong>料金:</strong>
                <ul>
                  <li>時間: {selectedParking.fees.hourly}円</li>
                  <li>1日: {selectedParking.fees.daily}円</li>
                  <li>月極: {selectedParking.fees.monthly}円</li>
                </ul>
              </div>
              <div>
                <strong>対応車種:</strong> {selectedParking.bikeTypes.join(', ')}
              </div>
            </div>
            <button className="navigate-btn">
              Google Mapsで経路案内
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default ParkingChat;
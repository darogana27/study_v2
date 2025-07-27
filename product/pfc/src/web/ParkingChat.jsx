import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import './ParkingChat.css';

const API_ENDPOINT = 'https://your-api-gateway-url.amazonaws.com/prod/chat';

// 選択肢フローの定義
const ChatFlow = {
  step1: {
    message: "どちらをお探しですか？🚲",
    options: [
      { id: "park", text: "🌳 公園の駐車場", icon: "🌳" },
      { id: "station", text: "🚉 駅周辺", icon: "🚉" },
      { id: "shopping", text: "🛒 商業施設", icon: "🛒" },
      { id: "hospital", text: "🏥 病院・施設", icon: "🏥" }
    ]
  },
  step2: {
    message: "何を重視しますか？",
    options: [
      { id: "free", text: "💰 無料", priority: "cost_free" },
      { id: "cheap", text: "💸 安い", priority: "cost_low" },
      { id: "near_station", text: "🚶 駅近", priority: "distance_station" },
      { id: "motorcycle", text: "🏍️ バイク可", priority: "vehicle_motorcycle" },
      { id: "bicycle", text: "🚲 自転車", priority: "vehicle_bicycle" }
    ]
  },
  step3: {
    message: "エリアを選択してください",
    options: [
      { id: "ikebukuro_west", text: "池袋西口周辺", area: "ikebukuro_west" },
      { id: "ikebukuro_east", text: "池袋東口周辺", area: "ikebukuro_east" },
      { id: "ikebukuro_center", text: "池袋駅周辺", area: "ikebukuro_center" },
      { id: "current", text: "📍 現在地周辺", area: "current_location" }
    ]
  }
};

const ParkingChat = () => {
  const [messages, setMessages] = useState([
    {
      type: 'bot',
      text: 'こんにちは！池袋エリアの駐輪場をお探しですか？',
      timestamp: new Date(),
      showOptions: true,
      step: 1
    }
  ]);
  const [currentStep, setCurrentStep] = useState(1);
  const [selections, setSelections] = useState({});
  const [isLoading, setIsLoading] = useState(false);
  const [selectedParking, setSelectedParking] = useState(null);
  const [parkingLots, setParkingLots] = useState([]);
  const [useTextInput, setUseTextInput] = useState(false);
  const [inputText, setInputText] = useState('');
  const messagesEndRef = useRef(null);

  // 自動スクロール
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // 選択肢処理
  const handleSelection = async (option) => {
    const userMessage = {
      type: 'user',
      text: option.text,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setIsLoading(true);

    // 選択情報を保存
    const updatedSelections = {
      ...selections,
      [`step${currentStep}`]: option
    };
    setSelections(updatedSelections);

    try {
      if (currentStep < 3) {
        // ステップ1-2: ローカル処理
        const nextStep = currentStep + 1;
        const stepData = ChatFlow[`step${nextStep}`];
        
        const botMessage = {
          type: 'bot',
          text: stepData.message,
          timestamp: new Date(),
          showOptions: true,
          step: nextStep,
          options: stepData.options
        };

        setMessages(prev => [...prev, botMessage]);
        setCurrentStep(nextStep);
      } else {
        // ステップ3: API呼び出し
        const response = await fetch(API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            selections: updatedSelections,
            step: currentStep,
            isSelectionMode: true
          })
        });

        const data = await response.json();
        
        const botMessage = {
          type: 'bot',
          text: data.response || data.message,
          parkingLots: data.parkingLots,
          suggestions: data.suggestions,
          timestamp: new Date(),
          showOptions: false
        };

        setMessages(prev => [...prev, botMessage]);
        if (data.parkingLots) {
          setParkingLots(data.parkingLots);
        }

        // リセット
        setCurrentStep(1);
        setSelections({});
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

  // テキスト入力送信
  const sendMessage = async () => {
    if (!inputText.trim()) return;

    const userMessage = {
      type: 'user',
      text: inputText,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setIsLoading(true);

    try {
      const response = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          message: inputText,
          isSelectionMode: false
        })
      });

      const data = await response.json();
      
      const botMessage = {
        type: 'bot',
        text: data.response || data.message,
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

  // 新しい検索を開始
  const startNewSearch = () => {
    setCurrentStep(1);
    setSelections({});
    setUseTextInput(false);
    
    const botMessage = {
      type: 'bot',
      text: 'どちらをお探しですか？🚲',
      timestamp: new Date(),
      showOptions: true,
      step: 1,
      options: ChatFlow.step1.options
    };
    
    setMessages(prev => [...prev, botMessage]);
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
                
                {/* 選択肢オプション */}
                {msg.showOptions && msg.options && (
                  <div className="selection-options">
                    {msg.options.map((option, idx) => (
                      <button
                        key={idx}
                        className="option-btn"
                        onClick={() => handleSelection(option)}
                        disabled={isLoading}
                      >
                        <span className="option-icon">{option.icon}</span>
                        <span className="option-text">{option.text}</span>
                      </button>
                    ))}
                  </div>
                )}
                
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
          <div className="mode-toggle">
            <button
              className={`mode-btn ${!useTextInput ? 'active' : ''}`}
              onClick={() => setUseTextInput(false)}
            >
              🎯 選択肢モード
            </button>
            <button
              className={`mode-btn ${useTextInput ? 'active' : ''}`}
              onClick={() => setUseTextInput(true)}
            >
              💬 フリー入力
            </button>
            <button
              className="new-search-btn"
              onClick={startNewSearch}
            >
              🔄 新しい検索
            </button>
          </div>
          
          {useTextInput ? (
            <div className="text-input-mode">
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
          ) : (
            <div className="selection-mode">
              <p className="selection-hint">
                上の選択肢をタップして進めてください 👆
              </p>
            </div>
          )}
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
import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import './ParkingChat.css';

// API Endpoint configuration - 環境変数またはデフォルトを使用
const API_ENDPOINT = process.env.REACT_APP_API_ENDPOINT || 'https://your-api-gateway-url.amazonaws.com/prod/chat';

// 選択肢フローの定義（東京全域対応）
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
      // 山手線主要駅
      { id: "shinjuku", text: "🏢 新宿駅周辺", area: "shinjuku", ward: "新宿区" },
      { id: "shibuya", text: "🎌 渋谷駅周辺", area: "shibuya", ward: "渋谷区" },
      { id: "ikebukuro", text: "🛍️ 池袋駅周辺", area: "ikebukuro", ward: "豊島区" },
      { id: "tokyo", text: "🏯 東京駅周辺", area: "tokyo", ward: "千代田区" },
      { id: "shinagawa", text: "🚅 品川駅周辺", area: "shinagawa", ward: "港区" },
      { id: "ueno", text: "🌸 上野駅周辺", area: "ueno", ward: "台東区" },
      
      // その他主要駅
      { id: "kichijoji", text: "🌲 吉祥寺駅周辺", area: "kichijoji", ward: "武蔵野市" },
      { id: "tachikawa", text: "🌺 立川駅周辺", area: "tachikawa", ward: "立川市" },
      { id: "machida", text: "🏞️ 町田駅周辺", area: "machida", ward: "町田市" },
      
      // 区域選択
      { id: "ward_select", text: "🗾 区・市から選択", area: "ward_selection" },
      { id: "current", text: "📍 現在地周辺", area: "current_location" }
    ]
  },
  // 新しい区・市選択ステップ
  ward_selection: {
    message: "どちらのエリアをお探しですか？",
    options: [
      // 23区
      { id: "chiyoda", text: "千代田区", area: "chiyoda", ward: "千代田区" },
      { id: "chuo", text: "中央区", area: "chuo", ward: "中央区" },
      { id: "minato", text: "港区", area: "minato", ward: "港区" },
      { id: "shinjuku_ward", text: "新宿区", area: "shinjuku", ward: "新宿区" },
      { id: "bunkyo", text: "文京区", area: "bunkyo", ward: "文京区" },
      { id: "taito", text: "台東区", area: "taito", ward: "台東区" },
      { id: "sumida", text: "墨田区", area: "sumida", ward: "墨田区" },
      { id: "koto", text: "江東区", area: "koto", ward: "江東区" },
      { id: "shinagawa_ward", text: "品川区", area: "shinagawa", ward: "品川区" },
      { id: "meguro", text: "目黒区", area: "meguro", ward: "目黒区" },
      { id: "ota", text: "大田区", area: "ota", ward: "大田区" },
      { id: "setagaya", text: "世田谷区", area: "setagaya", ward: "世田谷区" },
      { id: "shibuya_ward", text: "渋谷区", area: "shibuya", ward: "渋谷区" },
      { id: "nakano", text: "中野区", area: "nakano", ward: "中野区" },
      { id: "suginami", text: "杉並区", area: "suginami", ward: "杉並区" },
      { id: "toshima", text: "豊島区", area: "toshima", ward: "豊島区" },
      { id: "kita", text: "北区", area: "kita", ward: "北区" },
      { id: "arakawa", text: "荒川区", area: "arakawa", ward: "荒川区" },
      { id: "itabashi", text: "板橋区", area: "itabashi", ward: "板橋区" },
      { id: "nerima", text: "練馬区", area: "nerima", ward: "練馬区" },
      { id: "adachi", text: "足立区", area: "adachi", ward: "足立区" },
      { id: "katsushika", text: "葛飾区", area: "katsushika", ward: "葛飾区" },
      { id: "edogawa", text: "江戸川区", area: "edogawa", ward: "江戸川区" },
      
      // 主要市部
      { id: "hachioji", text: "八王子市", area: "hachioji", ward: "八王子市" },
      { id: "tachikawa_city", text: "立川市", area: "tachikawa", ward: "立川市" },
      { id: "musashino", text: "武蔵野市", area: "musashino", ward: "武蔵野市" },
      { id: "mitaka", text: "三鷹市", area: "mitaka", ward: "三鷹市" },
      { id: "fuchu", text: "府中市", area: "fuchu", ward: "府中市" },
      { id: "chofu", text: "調布市", area: "chofu", ward: "調布市" },
      { id: "machida_city", text: "町田市", area: "machida", ward: "町田市" },
      { id: "nishitokyo", text: "西東京市", area: "nishitokyo", ward: "西東京市" }
    ]
  }
};

const ParkingChat = () => {
  const [messages, setMessages] = useState([
    {
      type: 'bot',
      text: 'こんにちは！東京全域の駐輪場をお探しですか？🚲',
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

  // 選択肢処理（東京全域対応）
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
      // 区・市選択の特別処理
      if (option.area === "ward_selection") {
        const stepData = ChatFlow.ward_selection;
        
        const botMessage = {
          type: 'bot',
          text: stepData.message,
          timestamp: new Date(),
          showOptions: true,
          step: 'ward_selection',
          options: stepData.options
        };

        setMessages(prev => [...prev, botMessage]);
        setCurrentStep('ward_selection');
      } else if (currentStep === 'ward_selection' || currentStep === 3) {
        // 最終ステップ: API呼び出し
        const response = await fetch(API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            selections: updatedSelections,
            step: currentStep,
            isSelectionMode: true,
            area: option.area,
            ward: option.ward
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
      } else if (currentStep < 3) {
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
          <h2>🚲 東京駐輪場アシスタント</h2>
          <p className="header-subtitle">東京全域の駐輪場を検索できます</p>
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
                    {msg.parkingLots.map((lot) => {
                      // データ形式統一
                      const available = lot.capacity?.available || lot.available || 0;
                      const total = lot.capacity?.total || lot.total || 0;
                      const dailyFee = lot.fees?.daily || lot.daily_fee || 0;
                      const walkTime = lot.walkTime || lot.walk_time || 0;
                      const distance = lot.distance || 0;
                      const openHours = lot.openHours || lot.hours || '24時間';
                      
                      return (
                        <div 
                          key={lot.id} 
                          className="parking-card"
                          onClick={() => setSelectedParking(lot)}
                        >
                          <h4>{lot.name}</h4>
                          <div className="parking-info">
                            <span className="available">
                              空き: {available}/{total}台
                            </span>
                            <span className="distance">
                              徒歩{walkTime}分 ({distance}m)
                            </span>
                          </div>
                          <div className="parking-details">
                            <span>💰 {dailyFee}円/日</span>
                            <span>🕐 {openHours}</span>
                            {lot.ward && <span>📍 {lot.ward}</span>}
                          </div>
                        </div>
                      );
                    })}
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
          center={[35.6762, 139.6503]} 
          zoom={11} 
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          />
          {parkingLots.map((lot) => {
            // 座標データの統一処理
            const lat = lot.coordinates?.lat || lot.lat || 35.7295;
            const lng = lot.coordinates?.lng || lot.lng || 139.7109;
            
            // 容量データの統一処理
            const available = lot.capacity?.available || lot.available || 0;
            const total = lot.capacity?.total || lot.total || 0;
            
            // 料金データの統一処理
            const dailyFee = lot.fees?.daily || lot.daily_fee || 0;
            
            return (
              <Marker 
                key={lot.id}
                position={[lat, lng]}
                eventHandlers={{
                  click: () => setSelectedParking(lot)
                }}
              >
                <Popup>
                  <div>
                    <h4>{lot.name}</h4>
                    <p>空き: {available}台</p>
                    <p>料金: {dailyFee}円/日</p>
                    {lot.ward && <p>エリア: {lot.ward}</p>}
                  </div>
                </Popup>
              </Marker>
            );
          })}
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
            {selectedParking.ward && <p className="ward">📍 {selectedParking.ward}</p>}
            <div className="detail-grid">
              <div>
                <strong>空き状況:</strong> {selectedParking.capacity?.available || selectedParking.available || 0}/{selectedParking.capacity?.total || selectedParking.total || 0}台
              </div>
              <div>
                <strong>営業時間:</strong> {selectedParking.openHours || selectedParking.hours || '24時間'}
              </div>
              <div>
                <strong>料金:</strong>
                <ul>
                  <li>時間: {selectedParking.fees?.hourly || selectedParking.hourly_fee || 0}円</li>
                  <li>1日: {selectedParking.fees?.daily || selectedParking.daily_fee || 0}円</li>
                  <li>月極: {selectedParking.fees?.monthly || selectedParking.monthly_fee || 0}円</li>
                </ul>
              </div>
              <div>
                <strong>対応車種:</strong> {(selectedParking.bikeTypes || selectedParking.vehicleTypes || []).join(', ')}
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
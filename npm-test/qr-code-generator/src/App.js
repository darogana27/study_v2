import React, { useState, useRef } from 'react';
import { Download, QrCode, Link, MessageSquare, User, Copy, Check } from 'lucide-react';
import QRCodeLib from 'qrcode';

const QRCodeGenerator = () => {
  const [activeTab, setActiveTab] = useState('url');
  const [qrData, setQrData] = useState('');
  const [copied, setCopied] = useState(false);
  const canvasRef = useRef(null);

  // URL用のフォーム状態
  const [urlData, setUrlData] = useState('');

  // テキスト用のフォーム状態
  const [textData, setTextData] = useState('');

  // 連絡先用のフォーム状態
  const [contactData, setContactData] = useState({
    name: '',
    phone: '',
    email: '',
    organization: '',
    url: ''
  });

  // QRコード生成関数
  const generateQRCode = async (data) => {
    if (!data || !canvasRef.current) return;
  
    try {
      const canvas = canvasRef.current;
      await QRCodeLib.toCanvas(canvas, data, {
        width: 300,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      });
    } catch (error) {
      console.error('QRコード生成エラー:', error);
    }
  };

  const handleGenerate = async () => {
    let data = '';
    
    switch (activeTab) {
      case 'url':
        // URLの場合、http://やhttps://がない場合は自動で追加
        data = urlData;
        if (data && !data.startsWith('http://') && !data.startsWith('https://')) {
          data = 'https://' + data;
        }
        break;
      case 'text':
        data = textData;
        break;
      case 'contact':
        // vCard形式で連絡先情報を生成
        data = `BEGIN:VCARD
  VERSION:3.0
  FN:${contactData.name}
  TEL:${contactData.phone}
  EMAIL:${contactData.email}
  ORG:${contactData.organization}
  URL:${contactData.url}
  END:VCARD`;
        break;
    }
  
    if (data) {
      setQrData(data);
      await generateQRCode(data);
    }
  };

  const downloadQRCode = () => {
    if (!canvasRef.current) return;
    
    const canvas = canvasRef.current;
    const link = document.createElement('a');
    link.download = 'qrcode.png';
    link.href = canvas.toDataURL();
    link.click();
  };

  const copyToClipboard = async () => {
    if (qrData) {
      await navigator.clipboard.writeText(qrData);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 p-4">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-cyan-400 to-purple-500 rounded-2xl mb-4 shadow-2xl">
            <QrCode className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 via-purple-400 to-pink-400 mb-3">
            QRコードジェネレーター
          </h1>
          <p className="text-gray-300 text-lg font-medium">次世代のQRコード生成ツール</p>
          <div className="flex justify-center mt-4">
            <div className="w-24 h-1 bg-gradient-to-r from-cyan-400 to-purple-500 rounded-full"></div>
          </div>
        </div>

        <div className="bg-white/10 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/20 p-8 mb-6">
          {/* タブナビゲーション */}
          <div className="flex space-x-2 mb-8 bg-black/20 p-2 rounded-2xl backdrop-blur-sm">
            <button
              onClick={() => setActiveTab('url')}
              className={`flex-1 flex items-center justify-center gap-3 py-4 px-6 rounded-xl transition-all duration-300 font-semibold ${
                activeTab === 'url'
                  ? 'bg-gradient-to-r from-cyan-500 to-purple-500 text-white shadow-lg shadow-cyan-500/25 scale-105'
                  : 'text-gray-300 hover:text-white hover:bg-white/10'
              }`}
            >
              <Link className="w-5 h-5" />
              URL
            </button>
            <button
              onClick={() => setActiveTab('text')}
              className={`flex-1 flex items-center justify-center gap-3 py-4 px-6 rounded-xl transition-all duration-300 font-semibold ${
                activeTab === 'text'
                  ? 'bg-gradient-to-r from-cyan-500 to-purple-500 text-white shadow-lg shadow-cyan-500/25 scale-105'
                  : 'text-gray-300 hover:text-white hover:bg-white/10'
              }`}
            >
              <MessageSquare className="w-5 h-5" />
              テキスト
            </button>
            <button
              onClick={() => setActiveTab('contact')}
              className={`flex-1 flex items-center justify-center gap-3 py-4 px-6 rounded-xl transition-all duration-300 font-semibold ${
                activeTab === 'contact'
                  ? 'bg-gradient-to-r from-cyan-500 to-purple-500 text-white shadow-lg shadow-cyan-500/25 scale-105'
                  : 'text-gray-300 hover:text-white hover:bg-white/10'
              }`}
            >
              <User className="w-5 h-5" />
              連絡先
            </button>
          </div>

          {/* フォーム */}
          <div className="mb-6">
            {activeTab === 'url' && (
              <div>
                <label className="block text-sm font-semibold text-gray-200 mb-3">
                  ウェブサイトURL
                </label>
                <input
                  type="url"
                  value={urlData}
                  onChange={(e) => setUrlData(e.target.value)}
                  placeholder="https://example.com"
                  className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm"
                />
              </div>
            )}

            {activeTab === 'text' && (
              <div>
                <label className="block text-sm font-semibold text-gray-200 mb-3">
                  テキスト内容
                </label>
                <textarea
                  value={textData}
                  onChange={(e) => setTextData(e.target.value)}
                  placeholder="QRコードに埋め込むテキストを入力してください"
                  rows={4}
                  className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm resize-none"
                />
              </div>
            )}

            {activeTab === 'contact' && (
              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-semibold text-gray-200 mb-3">
                    氏名
                  </label>
                  <input
                    type="text"
                    value={contactData.name}
                    onChange={(e) => setContactData({...contactData, name: e.target.value})}
                    placeholder="山田太郎"
                    className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-200 mb-3">
                    電話番号
                  </label>
                  <input
                    type="tel"
                    value={contactData.phone}
                    onChange={(e) => setContactData({...contactData, phone: e.target.value})}
                    placeholder="090-1234-5678"
                    className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-200 mb-3">
                    メールアドレス
                  </label>
                  <input
                    type="email"
                    value={contactData.email}
                    onChange={(e) => setContactData({...contactData, email: e.target.value})}
                    placeholder="example@company.com"
                    className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-200 mb-3">
                    組織・会社名
                  </label>
                  <input
                    type="text"
                    value={contactData.organization}
                    onChange={(e) => setContactData({...contactData, organization: e.target.value})}
                    placeholder="株式会社サンプル"
                    className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-200 mb-3">
                    ウェブサイト
                  </label>
                  <input
                    type="url"
                    value={contactData.url}
                    onChange={(e) => setContactData({...contactData, url: e.target.value})}
                    placeholder="https://company.com"
                    className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl focus:ring-2 focus:ring-cyan-400 focus:border-cyan-400 transition-all duration-300 text-white placeholder-gray-400 backdrop-blur-sm"
                  />
                </div>
              </div>
            )}
          </div>

          {/* 生成ボタン */}
          <button
            onClick={handleGenerate}
            className="w-full bg-gradient-to-r from-cyan-500 to-purple-500 text-white py-4 px-8 rounded-xl font-bold text-lg hover:from-cyan-600 hover:to-purple-600 transition-all duration-300 shadow-lg shadow-cyan-500/25 hover:shadow-xl hover:shadow-cyan-500/40 transform hover:scale-105"
          >
            ✨ QRコードを生成 ✨
          </button>
        </div>

        {/* QRコード表示エリア */}
        {qrData && (
          <div className="bg-white/10 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/20 p-8 text-center">
            <h2 className="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-purple-400 mb-6">🎯 生成されたQRコード</h2>
            
            <div className="bg-white/20 backdrop-blur-sm rounded-2xl p-8 mb-8 border border-white/30">
              <canvas
                ref={canvasRef}
                className="mx-auto border-4 border-white/30 rounded-2xl shadow-2xl"
                style={{ maxWidth: '100%', height: 'auto' }}
              />
            </div>

            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-6">
              <button
                onClick={downloadQRCode}
                className="flex items-center justify-center gap-3 bg-gradient-to-r from-green-500 to-emerald-500 text-white py-4 px-8 rounded-xl font-semibold hover:from-green-600 hover:to-emerald-600 transition-all duration-300 shadow-lg shadow-green-500/25 hover:shadow-xl hover:shadow-green-500/40 transform hover:scale-105"
              >
                <Download className="w-5 h-5" />
                ダウンロード
              </button>
              <button
                onClick={copyToClipboard}
                className="flex items-center justify-center gap-3 bg-gradient-to-r from-blue-500 to-indigo-500 text-white py-4 px-8 rounded-xl font-semibold hover:from-blue-600 hover:to-indigo-600 transition-all duration-300 shadow-lg shadow-blue-500/25 hover:shadow-xl hover:shadow-blue-500/40 transform hover:scale-105"
              >
                {copied ? <Check className="w-5 h-5" /> : <Copy className="w-5 h-5" />}
                {copied ? 'コピー済み ✅' : 'データをコピー'}
              </button>
            </div>

            <div className="text-sm text-gray-300 bg-black/20 backdrop-blur-sm rounded-xl p-6 border border-white/10">
              <p className="font-semibold mb-3 text-cyan-300">💾 埋め込まれたデータ：</p>
              <p className="break-all font-mono text-gray-200">{qrData}</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default QRCodeGenerator;
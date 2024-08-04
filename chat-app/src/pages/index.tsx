import "@chatscope/chat-ui-kit-styles/dist/default/styles.min.css";
import {
  MainContainer,
  ChatContainer,
  MessageList,
  Message,
  MessageInput,
} from "@chatscope/chat-ui-kit-react";
import Head from "next/head";
import { useEffect, useState } from "react";

const LOCAL_STORED_USER = "猫";

type Messages = {
  message: string;
  send_user: string;
}[];

type Response = {
  statusCode: number;
  body: string;
};

export default function Home() {
  const [messages, setMessages] = useState<Messages>([]);
  const [socket, setSocket] = useState<WebSocket>();

  useEffect(() => {
    const getAllMessages = async () => {
      const res = await fetch("REST APIのURL");
      const resJson: Response = await res.json();

      setMessages(JSON.parse(resJson.body).messages);
    };

    getAllMessages();

    const socket = new WebSocket("WebSocket APIのURL");

    setSocket(socket);

    socket.onmessage = (event) => {
      const newMessages = JSON.parse(event.data).messages;
      if (newMessages) setMessages(newMessages);
    };

    return () => {
      socket.close();
    };
  }, []);

  const handleSend = (innerHtml: string, textContent: string) => {
    socket?.send(
      JSON.stringify({
        action: "sendMessage",
        data: {
          send_user: LOCAL_STORED_USER,
          message: textContent,
        },
      })
    );
  };

  return (
    <>
      <Head>
        <title>チャットアプリケーション</title>
        <meta name="description" content="チャットアプリケーション" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <main>
        <div style={{ margin: "0 auto", width: "400px", height: "500px" }}>
          <MainContainer>
            <ChatContainer>
              <MessageList>
                {messages.map((message, i) => (
                  <div key={i}>
                    <Message
                      model={{
                        message: message.message,
                        sender: message.send_user,
                        direction:
                          message.send_user == LOCAL_STORED_USER
                            ? "outgoing"
                            : "incoming",
                        position: "normal",
                      }}
                    />
                    <Message.Footer
                      style={
                        message.send_user == LOCAL_STORED_USER
                          ? { textAlign: "right", display: "block" }
                          : undefined
                      }
                      sender={message.send_user}
                    >
                      {message.send_user}
                    </Message.Footer>
                  </div>
                ))}
              </MessageList>
              <MessageInput onSend={handleSend} />
            </ChatContainer>
          </MainContainer>
        </div>
      </main>
    </>
  );
}
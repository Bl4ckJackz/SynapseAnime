"use client";

import { useState, useRef, useEffect } from "react";
import { aiService } from "@/services/ai.service";
import { Button } from "@/components/ui/Button";
import type { ChatMessage } from "@/types/chat";

export default function ChatPage() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (!input.trim() || loading) return;

    const userMsg: ChatMessage = {
      id: crypto.randomUUID(),
      content: input.trim(),
      isUser: true,
      timestamp: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setLoading(true);

    try {
      const chatHistory = [
        ...messages.map((m) => ({
          role: m.isUser ? "user" : "assistant",
          content: m.content,
        })),
        { role: "user", content: userMsg.content },
      ];

      const response = await aiService.chat(chatHistory);
      const assistantMsg: ChatMessage = {
        id: response.id || crypto.randomUUID(),
        content: response.content || "I couldn't generate a response.",
        isUser: false,
        timestamp: new Date().toISOString(),
        recommendations: response.recommendations,
      };
      setMessages((prev) => [...prev, assistantMsg]);
    } catch {
      setMessages((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          content: "Sorry, I encountered an error. Please try again.",
          isUser: false,
          timestamp: new Date().toISOString(),
        },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-[var(--color-border)] p-4">
        <h1 className="text-lg font-bold text-[var(--color-text)]">
          AI Anime Chat
        </h1>
        <p className="text-xs text-[var(--color-text-muted)]">
          Ask for anime recommendations, discuss your favorites, or get suggestions
        </p>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && (
          <div className="flex h-full items-center justify-center">
            <p className="text-sm text-[var(--color-text-muted)]">
              Start a conversation to get anime recommendations!
            </p>
          </div>
        )}
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${msg.isUser ? "justify-end" : "justify-start"}`}
          >
            <div
              className={`max-w-[80%] rounded-lg px-4 py-2 text-sm ${
                msg.isUser
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text)] border border-[var(--color-border)]"
              }`}
            >
              <p className="whitespace-pre-wrap">{msg.content}</p>
              {msg.recommendations && msg.recommendations.length > 0 && (
                <div className="mt-3 space-y-2">
                  {msg.recommendations.map((anime) => (
                    <a
                      key={anime.id}
                      href={`/anime/${anime.id}`}
                      className="block rounded-md border border-[var(--color-border)] bg-[var(--color-bg)] p-2 transition-colors hover:bg-[var(--color-surface-hover)]"
                    >
                      <p className="font-medium text-[var(--color-primary)]">
                        {anime.title}
                      </p>
                      <p className="text-xs text-[var(--color-text-muted)]">
                        Rating: {anime.rating} | {anime.genres?.join(", ")}
                      </p>
                    </a>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex justify-start">
            <div className="rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] px-4 py-2 text-sm text-[var(--color-text-muted)]">
              Thinking...
            </div>
          </div>
        )}
        <div ref={endRef} />
      </div>

      <form
        onSubmit={handleSend}
        className="flex gap-2 border-t border-[var(--color-border)] p-4"
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask about anime..."
          className="flex-1 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
        />
        <Button type="submit" loading={loading} disabled={!input.trim()}>
          Send
        </Button>
      </form>
    </div>
  );
}

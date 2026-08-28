# StudentAgent Roadmap & Pending Tasks

## 1. Tavily API Key Configuration
- [ ] Paste active Tavily API Key (`tvly-...`) into `Secrets.swift` (line 61) or in-app Settings under "TAVILY WEB SEARCH API".
- [ ] Verify web search returns live results and citations when Search Mode is toggled in chat bar.

## 2. Forwarded Email & MIME Parsing Resolution ("i-convo" Issue)
- [ ] Refactor `extractBody(from:)` in `GmailService.swift` to recursively traverse nested MIME parts (`multipart/alternative`, `multipart/related`, `multipart/mixed`, `message/rfc822`).
- [ ] Add forwarded email header parser to extract original sender, timestamp, and school subject from `---------- Forwarded message ---------` blocks.
- [ ] Test with forwarded UIUC / campus announcement digests.

## 3. Local Model Migration (Apple M5 Pro - 24GB Unified Memory)
- [ ] Install local server backend (Ollama / MLX / llama-server) running Qwen 2.5 14B / Llama 3.3 8B / DeepSeek-R1-Distill-Qwen-14B with OpenAI-compatible endpoint.
- [ ] Expose local server over LAN or secure tunnel (Tailscale / Cloudflare Tunnel / ngrok) to iOS app.
- [ ] Update `AppConfig.deepSeekBaseURL` or add Local Model Provider switch in Settings.

## 4. Mac Always-On / Clamshell Mode
- [ ] Configure `pmset` / `caffeinate` / `Amphetamine` to prevent sleep when lid is closed.

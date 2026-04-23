message persistence (offline queue)
👉 process supervision for user crashes
👉 group chat (process-per-group)
👉 WebSocket gateway (Android connection layer

STEP 1: wire chat_router → chat_user processes

(real message delivery path)

👉 STEP 2: integrate ETS registry into routing

(actual lookup + delivery)

👉 STEP 3: simulate full chat flow (alice → bob)
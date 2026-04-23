# Mobile API Integration Guide

This guide helps Android/iOS teams integrate chat, group payments, offline sync, and realtime resume endpoints.

## Base Conventions

- Base URL: `https://<host>:<port>/v1`
- Auth: Bearer token in header
  - `Authorization: Bearer <token>`
- Content type:
  - Request: `application/json`
  - Response: `application/json`
- Success envelope:
  - `status`, `code`, `message`, `data`
- Error envelope:
  - `status`, `code`, `message`

---

## 1) Authentication and Session

### Login

- `POST /auth/login`
- Use this to get user session token.

### Verify Session

- `POST /auth/verify`
- Use before sensitive actions or app resume checks.

> Always cache token securely (Keychain/EncryptedSharedPrefs) and refresh app state on 401.

---

## 2) Group Messaging and Payments

## 2) Groups and Membership

### Create group

- `POST /groups`
- Body:

```json
{
  "name": "Umoja Welfare",
  "purpose": "welfare",
  "target": 100000,
  "visibility": "public"
}
```

Response:

```json
{
  "status": "success",
  "code": "ok",
  "message": "request successful",
  "data": {
    "group_id": "grp_abc123"
  }
}
```

### List groups for current user

- `GET /groups`

Returns summaries including:

- `group_id`, `name`, `purpose`, `visibility`
- `wallet_balance`, `target`, `progress`
- `participant_count`, `my_role`

### Get one group details

- `GET /groups/:id`

Returns group info + participants list.

### List participants

- `GET /groups/:id/participants`

### Add participant by phone (admin)

- `POST /groups/:id/participants`
- Body:

```json
{
  "phone": "254712345678"
}
```

### Promote participant to admin (admin)

- `POST /groups/:id/participants/:phone/promote`

### Demote participant to member (admin)

- `POST /groups/:id/participants/:phone/demote`

### Remove participant (admin)

- `DELETE /groups/:id/participants/:phone`

### Leave group (self)

- `POST /groups/:id/participants/leave`

or

- `DELETE /groups/:id/participants/leave`

Notes:

- Creator is auto-added as first admin when group is created.
- Promotion/demotion and membership updates are audited server-side.

---

## 3) Group Messaging and Payments

### Post Group Announcement (admin/creator)

- `POST /groups/:group_id/chat_message/announcement`
- Body:

```json
{
  "message": "Monthly contribution window closes on Friday."
}
```

### Simulate Group Contribution (chat payment)

- `POST /groups/:group_id/chat_payment/contribute`
- Body:

```json
{
  "amount": 500,
  "user_id": "u_123",
  "receipt": "mpesa_sim_001"
}
```

### Withdraw From Group Wallet (admin/treasurer)

- `POST /groups/:group_id/chat_payment/withdraw`
- Body:

```json
{
  "amount": 1000
}
```

---

## 4) Offline Sync and Reconnect (HTTP)

Use these endpoints for app cold start, offline recovery, and gap repair.

### Catch-up per group

- `GET /groups/:group_id/messages?after_seq=<int>&limit=<int>&device_id=<id>`

Example:

`GET /groups/g1/messages?after_seq=120&limit=50&device_id=android-1`

Response fields:

- `messages`: ordered list after `after_seq`
- `paging.next_cursor`: save as latest cursor
- `paging.has_more`: paginate until false
- `ack.ack_seq`: server ack for this device

### Ack delivered/persisted messages

- `POST /groups/:group_id/acks`
- Body:

```json
{
  "device_id": "android-1",
  "ack_seq": 150
}
```

Notes:

- Ack is monotonic (server keeps max).
- Send ack only after message is saved in local DB.

### Bulk resume across many groups

- `POST /sync/resume`
- Body:

```json
{
  "device_id": "android-1",
  "updated_groups_only": true,
  "cursors": [
    { "group_id": "g1", "after_seq": 120, "limit": 50 },
    { "group_id": "g2", "after_seq": 0, "limit": 50 }
  ]
}
```

Response:

- `groups[]`: per-group status + messages + paging + ack
- `summary`: `total_groups`, `returned_groups`, `updated_count`, `error_count`

Recommended mobile flow:

1. On reconnect call `/sync/resume`.
2. Persist returned messages in order.
3. Call `/groups/:group_id/acks` with highest contiguous seq.
4. Repeat until `has_more = false` for each group.

---

## 5) Realtime WebSocket Resume

Endpoint:

- `GET /ws?group_id=<groupId>&after_seq=<int>`
- Header: `Authorization: Bearer <token>`

Server sends welcome frame:

```json
{ "op": "welcome", "protocol": "resume-v1" }
```

Client operations:

- Resume:

```json
{ "op": "resume", "group_id": "g1", "after_seq": 120, "limit": 50 }
```

- Ack:

```json
{ "op": "ack", "group_id": "g1", "device_id": "android-1", "ack_seq": 150 }
```

- Keepalive:

```json
{ "op": "ping" }
```

Best practice:

- Treat websocket as fast-path only.
- Use HTTP sync as source of truth for missed gaps.
- Dedupe by `seq` and/or message id in local database.

---

## 6) Financial Statements and Receipts

### Group monthly statement

- `GET /groups/:group_id/statements?month=YYYY-MM`

Response includes:

- `summary.gross_in`
- `summary.gross_out`
- `summary.fees`
- `summary.net`
- `entries[]`

### Receipt lookup

- `GET /groups/:group_id/receipts/:receipt_id`

Use for contributor history and receipt drill-down screens.

---

## 7) Compliance and Disputes

### Submit KYC details

- `POST /compliance/kyc/submit`

### AML screening request

- `POST /compliance/aml/screen`

### Create dispute

- `POST /compliance/disputes/:group_id`

### Resolve dispute

- `POST /compliance/disputes/:id/resolve`

### Audit export

- `GET /compliance/audit/export?actor_id=<id>&action=<atom>&entity_type=<atom>`

---

## 8) Notifications

### List queued notifications for authenticated user

- `GET /notifications`

Current event triggers include:

- New contribution
- Withdrawal completed
- Group announcement

---

## 9) Operations APIs (Admin Tools)

### Dashboard snapshot

- `GET /ops/dashboard`

### Incident list

- `GET /ops/incidents`

### Manual retry failed job

- `POST /ops/retries/:job_id`

---

## 10) Client-Side Integration Checklist

- Persist per-group `next_cursor` locally.
- Persist per-group per-device `ack_seq`.
- Use transactional local writes for message batches.
- Only ack persisted messages.
- Re-run `/sync/resume` after app foreground.
- Backoff websocket reconnect: 1s, 2s, 4s, 8s, max 30s.
- On 401: clear session and force re-auth.
- On 403 for a group: remove group from active sync set.

---

## 11) Suggested Minimum Screens

- Group chat timeline (merged social + financial messages)
- Contribution confirmation + receipt detail
- Wallet statement (month selector)
- Notifications inbox
- Dispute submission status

---

## 12) Known Current Limits (Important)

- Push providers (FCM/APNs) are not yet externally wired; notifications are currently queued server-side.
- Some ops/compliance endpoints should be gated behind stricter server-side admin authorization before production rollout.
- Full production websocket fanout/presence across multiple nodes is still evolving; keep HTTP sync fallback enabled at all times.

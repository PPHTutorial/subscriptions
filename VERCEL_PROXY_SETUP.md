# Vercel Proxy Server Setup Guide

## Overview

The app uses a Vercel proxy server to hide API keys and handle server-side operations. All sensitive API calls (Gmail, Outlook, OpenAI, etc.) are routed through the Vercel proxy.

## Architecture

```
Flutter App → Vercel Proxy → External APIs (Gmail, Outlook, OpenAI, etc.)
```

## Vercel Proxy Endpoints

### 1. Email Scanning (`/api/email/scan`)
- **Method**: POST
- **Body**:
  ```json
  {
    "provider": "gmail" | "outlook",
    "accessToken": "user_access_token",
    "maxResults": 50,
    "since": "2024-01-01T00:00:00Z" // optional
  }
  ```
- **Response**:
  ```json
  {
    "emails": [
      {
        "id": "message_id",
        "subject": "Subscription renewal",
        "body": "Your subscription...",
        "date": "2024-01-01T00:00:00Z"
      }
    ]
  }
  ```

### 2. AI Insights (`/api/ai/insights`)
- **Method**: POST
- **Body**:
  ```json
  {
    "subscriptions": [
      {
        "id": "...",
        "serviceName": "Netflix",
        "cost": 9.99,
        ...
      }
    ]
  }
  ```
- **Response**:
  ```json
  {
    "insights": [
      {
        "type": "waste",
        "title": "Potential Waste Detected",
        "message": "...",
        "severity": "high"
      }
    ]
  }
  ```

### 3. OAuth Token Exchange (`/api/auth/oauth`)
- **Method**: POST
- **Body**:
  ```json
  {
    "provider": "gmail" | "outlook",
    "code": "oauth_authorization_code",
    "redirectUri": "com.codeink.stsl.subscriptions://callback"
  }
  ```
- **Response**:
  ```json
  {
    "accessToken": "access_token",
    "refreshToken": "refresh_token",
    "expiresIn": 3600
  }
  ```

## Vercel Serverless Function Example

Create `api/email/scan.ts` in your Vercel project:

```typescript
import type { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { provider, accessToken, maxResults, since } = req.body;

  // Validate input
  if (!provider || !accessToken) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }

  try {
    let emails = [];

    if (provider === 'gmail') {
      // Use Gmail API with accessToken
      // API keys are stored in Vercel environment variables
      const GMAIL_API_KEY = process.env.GMAIL_API_KEY;
      const GMAIL_CLIENT_ID = process.env.GMAIL_CLIENT_ID;
      const GMAIL_CLIENT_SECRET = process.env.GMAIL_CLIENT_SECRET;
      
      // Fetch emails from Gmail API
      // Implementation here...
    } else if (provider === 'outlook') {
      // Use Microsoft Graph API
      const OUTLOOK_CLIENT_ID = process.env.OUTLOOK_CLIENT_ID;
      const OUTLOOK_CLIENT_SECRET = process.env.OUTLOOK_CLIENT_SECRET;
      
      // Fetch emails from Outlook API
      // Implementation here...
    }

    return res.status(200).json({ emails });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to scan emails' });
  }
}
```

## Environment Variables in Vercel

Set these in your Vercel project settings:

```
GMAIL_CLIENT_ID=your_gmail_client_id
GMAIL_CLIENT_SECRET=your_gmail_client_secret
OUTLOOK_CLIENT_ID=your_outlook_client_id
OUTLOOK_CLIENT_SECRET=your_outlook_client_secret
OPENAI_API_KEY=your_openai_api_key (optional)
ANTHROPIC_API_KEY=your_anthropic_api_key (optional)
```

## Configuration

Update `lib/core/config/app_config.dart`:

```dart
static const String vercelProxyUrl = 'https://your-app.vercel.app/api';
```

## Security Notes

- ✅ API keys are never exposed to the client
- ✅ All sensitive operations happen server-side
- ✅ OAuth tokens are handled securely
- ✅ Rate limiting can be implemented on the proxy
- ✅ Request validation and sanitization


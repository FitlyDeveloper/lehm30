# Fitness App with Food Analysis API

A secure implementation of a food analysis API for use with the Fitness App. This repository contains the API server code that handles secure processing of food images using OpenAI's Vision API.

## Overview

This is a clean implementation for deploying to Render.com, which avoids the limitations of Firebase Functions while maintaining security of API keys.

## Getting Started

### Prerequisites

- Node.js v18 or higher
- An OpenAI API key with access to GPT-4 Vision (gpt-4o model)

### Local Development

1. Clone this repository
2. Navigate to the api-server directory
3. Install dependencies:
   ```
   npm install
   ```
4. Create a `.env` file from the example:
   ```
   cp .env.example .env
   ```
5. Add your OpenAI API key to the `.env` file
6. Start the development server:
   ```
   npm run dev
   ```

The server will start on port 3000 by default.

## Deployment

This server is designed to be deployed to Render.com:

1. Push this repository to GitHub
2. Create a new Web Service on Render.com
3. Connect your GitHub repository
4. Configure the build settings:
   - Build Command: `cd api-server && npm install`
   - Start Command: `cd api-server && npm start`
5. Add the necessary environment variables:
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `ALLOWED_ORIGINS`: Comma-separated list of allowed origins
   - `RATE_LIMIT`: Request limits per minute (default: 30)
   - `DEBUG_MODE`: Enable debug logging (true/false)

## API Usage

### Analyze Food Image

**Endpoint:** `POST /api/analyze-food`

**Request Body:**
```json
{
  "image": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAA..."
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "meal": [
      {
        "dish": "Chicken Salad",
        "calories": 350,
        "macronutrients": {
          "protein": 25,
          "carbohydrates": 15,
          "fat": 20
        },
        "ingredients": ["chicken", "lettuce", "tomato", "avocado"]
      }
    ]
  }
}
```

## Security Considerations

- The OpenAI API key is stored securely on the server and never exposed to clients
- CORS protection ensures only authorized origins can access the API
- Rate limiting prevents abuse of the API

## License

MIT

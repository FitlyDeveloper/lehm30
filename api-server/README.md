# Food Analyzer API Server

A secure API server for food image analysis using OpenAI's Vision model.

## Features

- Secure server-side OpenAI API key storage
- CORS protection with configurable allowed origins
- Rate limiting to prevent abuse
- Error handling and logging

## Setup and Deployment

### Local Development

1. Clone this repository
2. Install dependencies:
   ```
   npm install
   ```
3. Copy the example environment file and fill in your OpenAI API key:
   ```
   cp .env.example .env
   ```
4. Edit the `.env` file and add your OpenAI API key
5. Start the development server:
   ```
   npm run dev
   ```

### Deployment Options

#### Deploying to Render.com

1. Create a new Web Service in your Render dashboard
2. Link to your GitHub repository
3. Set the build command to `npm install`
4. Set the start command to `npm start`
5. Add environment variables (especially `OPENAI_API_KEY`)
6. Deploy

#### Deploying to Heroku

1. Create a new Heroku app
2. Connect to your GitHub repository
3. Set environment variables in the Heroku dashboard
4. Deploy the app

## API Usage

### Analyze Food Image

**Endpoint:** `POST /api/analyze-food`

**Request Body:**
```json
{
  "image": "data:image/jpeg;base64,/9j/4AAQSkZ..."
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "meal": [
      {
        "dish": "Grilled Salmon with Vegetables",
        "calories": 450,
        "macronutrients": {
          "protein": 35,
          "carbohydrates": 20,
          "fat": 25
        },
        "ingredients": [
          "salmon",
          "asparagus",
          "bell peppers",
          "olive oil",
          "lemon",
          "herbs"
        ]
      }
    ]
  }
}
```

## Security Considerations

- The OpenAI API key is stored securely on the server and never exposed to clients
- CORS protection ensures only authorized origins can access the API
- Rate limiting prevents abuse of the API

## Configuration

All configuration is done through environment variables:

- `OPENAI_API_KEY`: Your OpenAI API key (required)
- `PORT`: Server port (default: 3000)
- `ALLOWED_ORIGINS`: Comma-separated list of allowed origins
- `RATE_LIMIT`: Maximum requests per minute (default: 30)
- `DEBUG_MODE`: Set to 'true' to enable debug logging 
# Fitness App with Food Analysis

A Flutter fitness application with advanced food analysis capabilities using OpenAI Vision API.

## Project Structure

- `/lib` - Flutter application code
- `/api-server` - Node.js API server for secure OpenAI API calls

## Local Development

### Flutter App

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run -d chrome --web-renderer canvaskit
   ```

### API Server

1. Navigate to the API server directory:
   ```bash
   cd api-server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file from `.env.example` and add your OpenAI API key:
   ```bash
   cp .env.example .env
   ```

4. Start the server:
   ```bash
   npm run dev
   ```

## Deploying to Render.com

1. Fork/clone this repository to your GitHub account

2. Sign up for [Render.com](https://render.com) if you haven't already

3. Create a new Web Service:
   - Connect your GitHub repository
   - Use the following settings:
     - Name: `food-analyzer-api`
     - Environment: `Node`
     - Build Command: `cd api-server && npm install`
     - Start Command: `cd api-server && npm start`
     - Environment Variables: Add your `OPENAI_API_KEY` and other variables from `.env.example`

4. The server will be deployed at a URL like: `https://food-analyzer-api.onrender.com`

5. Update the `baseUrl` in `lib/services/food_analyzer_api.dart` with your Render.com deployment URL

## Features

- Food image analysis using OpenAI Vision API
- Secure API server to protect API keys
- Responsive UI for mobile and web

## License

MIT

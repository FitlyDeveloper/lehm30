# OpenAI Vision API Integration for Food Analysis

This document outlines the implementation of the OpenAI Vision API integration for analyzing food images in the SnapFood screen.

## Overview

The integration allows users to take photos of meals using the camera or select images from their gallery, which are then sent to the OpenAI Vision API for analysis. The analysis provides nutritional information including calories, macronutrients, and ingredients.

## Implementation Details

### Backend (Firebase Functions)

1. Added a new Firebase Function `analyzeFoodImage` in `functions/index.js` that:
   - Securely calls the OpenAI Vision API with a food image
   - Processes the image as base64
   - Returns structured nutritional analysis
   - Includes a demo mode for testing without an image

2. Security measures:
   - API key is stored in Firebase config, not in client code
   - All requests go through a secure Firebase Function
   - Error handling and logging are implemented

### Frontend (Flutter App)

1. Updated `lib/NewScreens/SnapFood.dart` to:
   - Convert captured/selected images to base64
   - Send images to the Firebase Function
   - Process and display the analysis results
   - Show loading feedback during analysis
   - Add automatic analysis when an image is captured or selected

2. User experience improvements:
   - Loading indicator while analyzing
   - Automatic analysis after capturing or selecting an image
   - Console logging of nutritional information (to be displayed in UI later)

## How to Use

### Setting Up the API Key

1. Obtain an OpenAI API key from [OpenAI Platform](https://platform.openai.com)

2. Set the API key in Firebase config:
   ```bash
   firebase functions:config:set openai.api_key="your_openai_api_key"
   ```

3. Update local config for testing:
   ```bash
   firebase functions:config:get > .runtimeconfig.json
   ```

### Deployment

Run the deployment script:
```bash
cd functions
bash deploy.sh
```

The script will:
- Check for and prompt for API keys if not configured
- Install dependencies
- Deploy the functions to Firebase

### Testing

1. Visual Food Analysis:
   - Open the app
   - Navigate to the SnapFood screen
   - Take a photo with the shutter button or select a photo with "Add Photo"
   - The analysis will run automatically and log results to the console

2. Local Function Testing:
   ```bash
   cd functions
   npm run test:vision
   ```

## Future Improvements

1. **UI Display**: Create a dedicated screen to display the nutritional analysis with a clean, user-friendly interface.

2. **Result Caching**: Cache analysis results to avoid duplicate API calls for the same image.

3. **Feedback System**: Allow users to correct or provide feedback on the nutritional analysis.

4. **Multiple Food Items**: Enable analysis of multiple food items in a single image.

## Security Notes

- The OpenAI API key is never exposed in client-side code.
- The Firebase Function acts as a secure proxy for API requests.
- Authentication isn't required for this feature (as specified).
- The implementation prevents direct sharing of the API key with mobile clients. 
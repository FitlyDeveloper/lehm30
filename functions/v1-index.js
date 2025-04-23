const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

// Initialize Firebase Admin
admin.initializeApp();

// Get the OpenAI API key from Firebase config
async function getOpenAIKey() {
  // Get OpenAI API key
  const apiKey = functions.config().openai?.api_key;
  if (!apiKey) {
    console.error("OpenAI API key not configured");
    throw new Error("OpenAI API key not configured. Set it using 'firebase functions:config:set openai.api_key=\"your_api_key_here\"'");
  }
  return apiKey;
}

// Process and analyze food images
exports.analyzeFoodImage = functions.https.onCall(async (data, context) => {
  try {
    // Validate the image is provided
    if (!data.image) {
      console.error("No image provided in the request");
      throw new functions.https.HttpsError("invalid-argument", "An image is required");
    }

    // Get the base64 image
    const base64Image = data.image;
    console.log(`Received image of size ${base64Image.length} bytes`);

    // Get the OpenAI API key
    const apiKey = await getOpenAIKey();

    // Call OpenAI API
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a nutrition expert analyzing food images. Return detailed nutritional information in JSON format with this structure: { "meal": [{ "dish": "Name of dish", "calories": "Total calories (number only)", "macronutrients": { "protein": "grams (number only)", "carbohydrates": "grams (number only)", "fat": "grams (number only)" }, "ingredients": ["ingredient1", "ingredient2", ...] }] }'
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': "What's in this meal? Please analyze the nutritional content and ingredients, providing calories and macronutrient breakdown."
              },
              {
                'type': 'image_url',
                'image_url': { 'url': base64Image }
              }
            ]
          }
        ],
        'max_tokens': 1000
      })
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`OpenAI API error: ${response.status}`, errorText);
      throw new functions.https.HttpsError(
        "internal",
        `Failed to analyze food image: API returned ${response.status}`
      );
    }
    
    const responseData = await response.json();
    console.log('OpenAI response received');
    
    if (!responseData.choices || 
        !responseData.choices[0] || 
        !responseData.choices[0].message ||
        !responseData.choices[0].message.content) {
      console.error('Invalid response format from OpenAI');
      throw new functions.https.HttpsError(
        "internal",
        "Invalid response from image analysis service"
      );
    }
    
    const content = responseData.choices[0].message.content;
    console.log('Content received, parsing response...');
    
    // Parse JSON from the response
    try {
      // Try to find JSON blocks in markdown (```json ... ```)
      const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/) || 
                       content.match(/{[\s\S]*?}/);
      
      if (jsonMatch) {
        // Clean the JSON string
        let jsonContent = jsonMatch[0];
        jsonContent = jsonContent.replace(/```json\n|```/g, '').trim();
        
        // Parse the JSON
        const analysisData = JSON.parse(jsonContent);
        console.log('Successfully parsed food analysis JSON');
        return analysisData;
      } else {
        // If no JSON found, try to parse the content directly
        try {
          const analysisData = JSON.parse(content);
          return analysisData;
        } catch (directParseError) {
          // If direct parsing fails, return raw text
          console.log('No structured JSON found in response');
          return { rawText: content };
        }
      }
    } catch (parseError) {
      console.error('Error parsing food analysis result:', parseError);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to parse analysis results"
      );
    }
  } catch (error) {
    console.error("Error in analyzeFoodImage:", error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      "internal",
      `Failed to analyze food image: ${error.message}`
    );
  }
}); 
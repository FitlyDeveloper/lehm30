// Simple API server for food analysis
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
const PORT = process.env.PORT || 3000;

// Debug startup
console.log('Starting server...');
console.log('Node environment:', process.env.NODE_ENV);
console.log('Current directory:', process.cwd());
console.log('OpenAI API Key present:', process.env.OPENAI_API_KEY ? 'Yes' : 'No');

// Configure CORS
app.use(cors({
  origin: '*',
  methods: ['POST', 'GET'],
  credentials: true
}));

// Body parser middleware
app.use(express.json({ limit: '10mb' }));

// Define routes
app.get('/', (req, res) => {
  console.log('Health check endpoint called');
  res.json({
    message: 'Food Analyzer API Server',
    status: 'operational'
  });
});

// OpenAI proxy endpoint for food analysis
app.post('/api/analyze-food', async (req, res) => {
  try {
    console.log('Analyze food endpoint called');
    
    // Check API key
    if (!process.env.OPENAI_API_KEY) {
      console.error('OpenAI API key not configured');
      return res.status(500).json({
        success: false,
        error: 'Server configuration error: OpenAI API key not set'
      });
    }
    
    const { image } = req.body;

    if (!image) {
      console.error('No image provided in request');
      return res.status(400).json({
        success: false,
        error: 'Image data is required'
      });
    }

    // Check image size (4MB limit)
    // For data URLs, the content is approximately 4/3 of the decoded size
    // So a 4MB image will be around 5.33MB in base64
    const MAX_SIZE = 4 * 1024 * 1024 * 1.4; // 4MB with encoding overhead
    if (image.length > MAX_SIZE) {
      console.error('Image too large:', Math.round(image.length/1024/1024), 'MB');
      return res.status(413).json({
        success: false,
        error: 'Image too large. Maximum size is 4MB.'
      });
    }

    // Debug logging
    console.log('Received image data, length:', image.length);

    // Call OpenAI API
    console.log('Calling OpenAI API...');
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'You are a nutrition expert analyzing food images. Return detailed nutritional information in JSON format with this structure: { "meal": [{ "dish": "Name of dish", "calories": "Total calories (number only)", "macronutrients": { "protein": "grams (number only)", "carbohydrates": "grams (number only)", "fat": "grams (number only)" }, "ingredients": ["ingredient1", "ingredient2", ...] }] }'
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: "What's in this meal? Please analyze the nutritional content and ingredients, providing calories and macronutrient breakdown."
              },
              {
                type: 'image_url',
                image_url: { url: image }
              }
            ]
          }
        ],
        max_tokens: 1000
      })
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('OpenAI API error:', response.status, errorData);
      return res.status(response.status).json({
        success: false,
        error: `OpenAI API error: ${response.status}`
      });
    }

    console.log('OpenAI API response received');
    const data = await response.json();
    
    if (!data.choices || 
        !data.choices[0] || 
        !data.choices[0].message || 
        !data.choices[0].message.content) {
      console.error('Invalid response format from OpenAI');
      return res.status(500).json({
        success: false,
        error: 'Invalid response from OpenAI'
      });
    }

    const content = data.choices[0].message.content;
    console.log('OpenAI API response content received');
    
    // Process and parse the response
    try {
      // First try direct parsing
      const parsedData = JSON.parse(content);
      console.log('Successfully parsed JSON response');
      return res.json({
        success: true,
        data: parsedData
      });
    } catch (error) {
      console.log('Direct JSON parsing failed, attempting to extract JSON from text');
      // Try to extract JSON from the text
      const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/) || 
                      content.match(/\{[\s\S]*\}/);
      
      if (jsonMatch) {
        const jsonContent = jsonMatch[0].replace(/```json\n|```/g, '').trim();
        try {
          const parsedData = JSON.parse(jsonContent);
          console.log('Successfully extracted and parsed JSON from text');
          return res.json({
            success: true,
            data: parsedData
          });
        } catch (err) {
          console.error('JSON extraction failed');
          // Return the raw text if JSON parsing fails
          return res.json({
            success: true,
            data: { text: content }
          });
        }
      } else {
        console.warn('No JSON pattern found in response');
        // Return the raw text if no JSON found
        return res.json({
          success: true,
          data: { text: content }
        });
      }
    }
  } catch (error) {
    console.error('Server error:', error);
    return res.status(500).json({
      success: false,
      error: 'Server error processing request'
    });
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`API Key configured: ${process.env.OPENAI_API_KEY ? 'Yes' : 'No'}`);
}); 
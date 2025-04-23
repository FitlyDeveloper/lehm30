const functions = require('firebase-functions');
const fetch = require('node-fetch');

// Basic food image analyzer
async function analyzeFoodImageImpl(imageData, apiKey) {
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
          'content': 'You are a nutrition expert. Analyze this food image and return JSON with format: {"meal":[{"dish":"Name","calories":100,"macronutrients":{"protein":10,"carbohydrates":10,"fat":5},"ingredients":["item1","item2"]}]}'
        },
        {
          'role': 'user',
          'content': [
            { 'type': 'text', 'text': "Analyze this meal's nutritional content." },
            { 'type': 'image_url', 'image_url': { 'url': imageData } }
          ]
        }
      ],
      'max_tokens': 800
    })
  });
  
  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }
  
  const result = await response.json();
  return result.choices[0].message.content;
}

// Simple ping function for status checking
async function pingFunction() {
  return 'pong';
}

// Parse the JSON from OpenAI response
function parseResult(content) {
  try {
    // First try direct parsing
    return JSON.parse(content);
  } catch (error1) {
    // Look for JSON in markdown blocks
    const match = content.match(/```(?:json)?\s*([\s\S]*?)\s*```/) || content.match(/\{[\s\S]*\}/);
    if (match) {
      const jsonText = match[0].replace(/```json\n|```/g, '').trim();
      return JSON.parse(jsonText);
    }
    // Fall back to returning raw text
    return { text: content };
  }
}

module.exports = { analyzeFoodImageImpl, parseResult, pingFunction }; 
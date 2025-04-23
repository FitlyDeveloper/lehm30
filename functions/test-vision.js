const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');

// Load the runtime config for local testing
let config = {};
try {
  const configPath = path.join(__dirname, '.runtimeconfig.json');
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } else {
    console.error('No .runtimeconfig.json file found. Please run "firebase functions:config:get > .runtimeconfig.json" first.');
    process.exit(1);
  }
} catch (error) {
  console.error('Error loading config:', error);
  process.exit(1);
}

const apiKey = config.openai?.api_key;
if (!apiKey) {
  console.error('OpenAI API key not found in config. Please set it using:');
  console.error('firebase functions:config:set openai.api_key="your_api_key_here"');
  console.error('Then run: firebase functions:config:get > .runtimeconfig.json');
  process.exit(1);
}

// OpenAI API endpoint
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

// Path to a test image (replace with an actual image path)
const TEST_IMAGE_PATH = path.join(__dirname, 'test-meal.jpg'); 

async function testOpenAIVisionApi() {
  console.log('Testing OpenAI Vision API...');
  
  // Check if test image exists
  if (!fs.existsSync(TEST_IMAGE_PATH)) {
    console.error(`Test image not found at ${TEST_IMAGE_PATH}`);
    console.log('Please add a test meal image named "test-meal.jpg" to the functions directory.');
    console.log('\nSkipping image test. Testing without image...');
    
    // Test the API without an image (text-only query)
    await testWithoutImage();
    return;
  }
  
  try {
    // Read the image file and convert to base64
    const imageBuffer = fs.readFileSync(TEST_IMAGE_PATH);
    const base64Image = imageBuffer.toString('base64');
    
    console.log(`Read image from ${TEST_IMAGE_PATH}, size: ${imageBuffer.length} bytes`);
    
    // Create the vision prompt with the image
    const messages = [
      {
        role: "system",
        content: "You are a nutrition expert analyzing food images. Return detailed nutritional information in JSON format. Include calories, macronutrients (protein, carbs, fat), and a list of visible ingredients. Be accurate but concise."
      },
      {
        role: "user",
        content: [
          {
            type: "text",
            text: "What's in this meal? Please analyze the nutritional content and ingredients, providing calories and macronutrient breakdown."
          },
          {
            type: "image_url",
            image_url: {
              url: `data:image/jpeg;base64,${base64Image}`
            }
          }
        ]
      }
    ];

    console.log('Making API request to OpenAI Vision API...');
    
    const response = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: "gpt-4o",
        messages: messages,
        max_tokens: 1000
      })
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error("OpenAI API error:", errorData);
      return;
    }

    const data = await response.json();
    
    console.log('\nAPI Response:');
    console.log('----------------');
    console.log(data.choices[0].message.content);
    console.log('----------------');
    
    // Try to parse JSON from the response if available
    try {
      const jsonMatch = data.choices[0].message.content.match(/```json\n([\s\S]*?)\n```/) || 
                      data.choices[0].message.content.match(/{[\s\S]*?}/);
                      
      if (jsonMatch) {
        const jsonContent = jsonMatch[0].replace(/```json\n|```/g, '').trim();
        console.log('\nExtracted JSON:');
        console.log(JSON.parse(jsonContent));
      }
    } catch (parseError) {
      console.warn("Unable to parse structured data from response:", parseError);
    }

  } catch (error) {
    console.error("Error calling OpenAI Vision API:", error);
  }
}

async function testWithoutImage() {
  console.log('Testing OpenAI API without an image (text-only)...');
  
  try {
    const messages = [
      {
        role: "system",
        content: "You are a nutrition expert. Return detailed nutritional information in JSON format."
      },
      {
        role: "user",
        content: "What are the nutritional values of a typical plate of spaghetti bolognese? Include calories, macronutrients, and main ingredients."
      }
    ];
    
    const response = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: "gpt-4-turbo",
        messages: messages,
        max_tokens: 1000
      })
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error("OpenAI API error:", errorData);
      return;
    }

    const data = await response.json();
    
    console.log('\nAPI Response (text-only):');
    console.log('----------------');
    console.log(data.choices[0].message.content);
    console.log('----------------');
    
  } catch (error) {
    console.error("Error calling OpenAI API:", error);
  }
}

// Main function
async function main() {
  console.log('OpenAI API Key found in config.');
  await testOpenAIVisionApi();
}

main().catch(console.error); 
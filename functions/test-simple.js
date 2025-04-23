const fetch = require('node-fetch');

// API Key directly for test (remove before committing)
const apiKey = "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";

// OpenAI API endpoint
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

async function testSimple() {
  console.log('Testing OpenAI API with a simple text-only query...');
  
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
    
    console.log('\nAPI Response:');
    console.log('----------------');
    console.log(data.choices[0].message.content);
    console.log('----------------');
    
  } catch (error) {
    console.error("Error calling OpenAI API:", error);
  }
}

// Run the test
testSimple().catch(console.error); 
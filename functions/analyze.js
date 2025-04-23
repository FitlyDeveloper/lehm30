const {onRequest, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const fetch = require("node-fetch");

// OpenAI API endpoint  
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

// Function to call OpenAI Vision API
async function callOpenAIVisionApi(base64Image) {
  try {
    // Get OpenAI API key from Firebase config
    const apiKey = functions.config().openai?.api_key;
    
    if (!apiKey) {
      logger.error("OpenAI API key not configured");
      throw new HttpsError("failed-precondition", "OpenAI API key not configured. Set it using 'firebase functions:config:set openai.api_key=\"your_api_key_here\"'");
    }

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

    logger.info("Calling OpenAI Vision API");
    
    // Log a small sample of the API request for debugging
    const sampleRequest = {
      model: "gpt-4o",
      messages: [
        { role: "system", content: "[system message]" },
        { 
          role: "user", 
          content: [
            { type: "text", text: "[text prompt]" },
            { type: "image_url", image_url: { url: `data:image/jpeg;base64,[first 20 chars of base64: ${base64Image.substring(0, 20)}...]` } }
          ]
        }
      ]
    };
    logger.info("Sample API request:", JSON.stringify(sampleRequest));
    
    // Make the actual request
    const requestBody = JSON.stringify({
      model: "gpt-4o", // Using gpt-4o instead of gpt-4-vision-preview
      messages: messages,
      max_tokens: 1000,
      temperature: 0.5
    });
    
    try {
      const response = await fetch(OPENAI_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: requestBody
      });

      // Handle HTTP error scenarios with more detail
      if (!response.ok) {
        let errorMessage = `HTTP error ${response.status}`;
        try {
          const errorData = await response.json();
          logger.error("OpenAI API error details:", errorData);
          errorMessage = `OpenAI API error: ${response.status} - ${JSON.stringify(errorData)}`;
        } catch (jsonError) {
          // If we can't parse the JSON, try to get the text
          try {
            const errorText = await response.text();
            errorMessage = `OpenAI API error: ${response.status} - ${errorText}`;
          } catch (textError) {
            // If we can't even get the text, just use the status
            errorMessage = `OpenAI API error: ${response.status} - Could not read error details`;
          }
        }
        
        logger.error(errorMessage);
        throw new HttpsError("internal", errorMessage);
      }

      // Process successful response
      const responseData = await response.json();
      logger.info("OpenAI Vision API response received successfully");
      logger.info("Response choice:", JSON.stringify(responseData.choices[0]));
      return responseData;
      
    } catch (fetchError) {
      // Handle network or parsing errors
      logger.error("Fetch error with OpenAI API:", fetchError);
      throw new HttpsError("internal", `Network error with OpenAI API: ${fetchError.message}`);
    }
  } catch (error) {
    logger.error("Error calling OpenAI Vision API:", error);
    throw new HttpsError("internal", `Failed to call OpenAI Vision API: ${error.message}`);
  }
}

// Function to analyze food images using OpenAI Vision API
exports.analyzeFood = onRequest({
  cors: true,
  region: "us-central1",
  timeoutSeconds: 120,
  memory: "2GiB"
}, async (request, response) => {
  try {
    logger.info("Food analysis request received");
    
    // Check if we're in simulation mode
    const simulateMode = request.query.simulate === 'true';
    if (simulateMode) {
      logger.info("Running in SIMULATION mode - returning mock data");
      return response.json({
        success: true,
        simulation: true,
        analysis: {
          calories: 420,
          macros: {
            protein: 12,
            carbs: 65,
            fat: 11
          },
          ingredients: [
            "Pasta",
            "Cream sauce", 
            "Herbs (likely parsley or basil)",
            "Olive oil",
            "Black pepper"
          ],
          description: "This appears to be a creamy pasta dish, likely fettuccine or rigatoni with a cream-based sauce. The dish is topped with fresh herbs, possibly parsley or basil. Estimated calories per serving shown."
        }
      });
    }
    
    // Extract image from request body
    let image;
    if (request.body && typeof request.body === 'object') {
      // Extract directly from request body object
      image = request.body.image;
      logger.info(`Found image in request body, length: ${image ? image.length : 'undefined'}`);
    } else if (request.rawBody) {
      // Try to parse raw request body
      try {
        const parsedBody = JSON.parse(request.rawBody.toString());
        image = parsedBody.image;
        logger.info(`Extracted image from raw request body, length: ${image ? image.length : 'undefined'}`);
      } catch (e) {
        logger.error("Failed to parse raw request body:", e);
      }
    }
    
    // Validate image
    if (!image) {
      logger.error("No image found in request");
      return response.status(400).json({
        success: false,
        error: "Image must be provided as base64 string"
      });
    }
    
    // Process the image
    logger.info(`Processing image, length: ${image.length}`);
    
    // Remove data URI prefix if present
    const hasPrefix = image.startsWith('data:image');
    if (hasPrefix) {
      logger.info("Removing data URI prefix");
    }
    const base64Image = image.replace(/^data:image\/\w+;base64,/, "");
    
    // Validate base64 data
    if (!base64Image || base64Image.trim() === "") {
      logger.error("Empty base64 image data");
      return response.status(400).json({
        success: false,
        error: "Invalid base64 image data"
      });
    }
    
    // Call the Vision API
    const apiResponse = await callOpenAIVisionApi(base64Image);
    const analysisText = apiResponse.choices[0].message.content;
    
    // Parse JSON from response if available
    let structuredAnalysis = null;
    try {
      // Try to extract JSON from response
      const jsonMatch = analysisText.match(/```json\n([\s\S]*?)\n```/) || 
                       analysisText.match(/{[\s\S]*?}/);
      
      if (jsonMatch) {
        structuredAnalysis = JSON.parse(jsonMatch[0].replace(/```json\n|```/g, '').trim());
      }
    } catch (parseError) {
      logger.warn("Unable to parse structured data from response:", parseError);
    }
    
    // Return the results
    return response.json({
      success: true,
      analysis: structuredAnalysis,
      rawAnalysis: analysisText
    });
  } catch (error) {
    logger.error("Error in analyzeFood:", error);
    return response.status(500).json({
      success: false,
      error: error.message || "Unknown error occurred"
    });
  }
}); 
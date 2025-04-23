const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { analyzeFoodImageImpl, parseResult, pingFunction } = require('./simple');

admin.initializeApp();

// Analyze food image function
exports.analyzeFoodImage = functions.https.onCall(async (data, context) => {
  try {
    // Validate input
    if (!data.image) {
      throw new functions.https.HttpsError("invalid-argument", "Image is required");
    }
    
    // Get API key
    const apiKey = functions.config().openai?.api_key;
    if (!apiKey) {
      throw new functions.https.HttpsError("failed-precondition", "API key not configured");
    }
    
    // Process image
    try {
      const content = await analyzeFoodImageImpl(data.image, apiKey);
      return parseResult(content);
    } catch (error) {
      throw new functions.https.HttpsError("internal", `Analysis failed: ${error.message}`);
    }
  } catch (error) {
    console.error("Function error:", error);
    throw error instanceof functions.https.HttpsError ? 
      error : 
      new functions.https.HttpsError("internal", error.message);
  }
}); 

// Simple ping function to check if system is available
exports.ping = functions.https.onCall(async (data, context) => {
  try {
    return await pingFunction();
  } catch (error) {
    console.error("Ping error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
}); 
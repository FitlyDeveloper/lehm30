/**
 * Test script to debug the analyzeFoodImage callable function locally
 */

// Require the function module
const functions = require('firebase-functions');
const fetch = require('node-fetch');

// Import the function implementation 
const index = require('./index');

// Configuration
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "your-key-here";
process.env.OPENAI_API_KEY = OPENAI_API_KEY;

// Mock data, context and response for callable function
const mockData = {
  image: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q=='
};

const mockContext = {
  auth: null
};

console.log("Testing analyzeFoodImage callable function...");
console.log("Data:", mockData);

// Define a mock HttpsError for testing
functions.https = functions.https || {};
functions.https.HttpsError = class HttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
    this.name = 'HttpsError';
  }
};

// Call the function and handle the result
async function testFunction() {
  try {
    // Call the function with the mock data
    console.log("Calling analyzeFoodImage function...");
    const result = await index.analyzeFoodImage(mockData, mockContext);
    console.log("Function executed successfully");
    console.log("Result:", JSON.stringify(result, null, 2));
    return result;
  } catch (error) {
    console.error("Function execution failed:");
    console.error("Error code:", error.code);
    console.error("Error message:", error.message);
    console.error("Error details:", error.details);
    throw error;
  }
}

// Run the test
testFunction()
  .then(() => {
    console.log("Test completed successfully");
    process.exit(0);
  })
  .catch(error => {
    console.error("Test failed:", error);
    process.exit(1);
  }); 
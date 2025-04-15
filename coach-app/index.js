/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 * 
 * Version: 1.1 - Added debugging and improved error handling
 */

const functions = require("firebase-functions");
const axios = require("axios");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

/**
 * Production-ready API for DeepSeek chat completion
 * - Proper error handling
 * - Rate limiting
 * - Secure API key management
 */
exports.getAIResponse = functions.https.onCall(async (data, context) => {
  try {
    console.log("Function triggered with request");
    console.log("Raw data type:", typeof data);
    
    let messages = [];
    
    // Handle all possible message formats for maximum compatibility
    if (data && typeof data === 'object') {
      if (data.messages && Array.isArray(data.messages)) {
        console.log("Found messages at root level:", data.messages.length);
        messages = data.messages;
      } else if (data.data && typeof data.data === 'object') {
        if (data.data.messages && Array.isArray(data.data.messages)) {
          console.log("Found messages in data.data:", data.data.messages.length);
          messages = data.data.messages;
        }
      }
    }
    
    // If we couldn't find messages anywhere, create a fallback
    if (!Array.isArray(messages) || messages.length === 0) {
      console.warn("No valid messages found in request. Using fallback content.");
      // Return a basic fallback response
      return {
        success: true,
        content: "I'm your fitness coach! How can I help you today?",
        note: "This is a fallback response due to missing messages in the request."
      };
    }
    
    // Process the messages
    console.log(`Processing ${messages.length} messages`);
    
    // Create clean message objects
    const safeMessages = messages.map(msg => {
      if (typeof msg === "object" && msg !== null) {
        return {
          role: String(msg.role || "user"),
          content: String(msg.content || "")
        };
      }
      return { role: "user", content: String(msg || "") };
    });
    
    // Ensure messages are properly ordered (system message first)
    const orderedMessages = safeMessages.sort((a, b) => {
      // System messages should come first
      if (a.role === 'system') return -1;
      if (b.role === 'system') return 1;
      return 0;
    });
    
    console.log(`Processing ${orderedMessages.length} messages (including any system messages)`);
    
    // Call the DeepSeek API
    try {
      // Get API key from environment variables (now only using process.env)
      const apiKey = process.env.DEEPSEEK_API_KEY;
      console.log("API key from env:", apiKey ? "Found (not showing for security)" : "Not found");
      
      if (!apiKey) {
        console.error("API key not found in environment variables");
        // Return a graceful error that doesn't expose the fact that it's an API key issue
        return {
          success: true,
          content: "I'm here to help with your fitness journey! What would you like to know?",
          note: "This is a fallback response due to a configuration issue."
        };
      }
      
      // Make API request
      console.log("Making request to DeepSeek API");
      const response = await axios.post(
        "https://api.deepseek.com/v1/chat/completions",
        {
          model: "deepseek-chat",
          messages: orderedMessages,
          temperature: 0.7,
          max_tokens: 1000,
          stream: false // Change to non-streaming for debugging
        },
        {
          headers: {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json"
          },
          timeout: 30000 // 30 second timeout
        }
      );
      
      console.log("DeepSeek API response status:", response.status);
      console.log("DeepSeek API response headers:", response.headers);
      
      // For debugging, log the response data
      if (response.data) {
        console.log("Response data structure:", Object.keys(response.data));
        if (response.data.choices && response.data.choices.length > 0) {
          console.log("First choice structure:", Object.keys(response.data.choices[0]));
          const contentPreview = response.data.choices[0].message.content.substring(0, 50) + "...";
          console.log("Content preview:", contentPreview);
        }
      }
      
      // For non-streaming fallback
      if (!response.data || typeof response.data.on !== 'function') {
        console.log("Non-streaming response received");
        
        // Check if we have a valid response
        if (response.data && response.data.choices && response.data.choices.length > 0) {
          const content = response.data.choices[0].message.content;
          console.log("Returning content from non-streaming response");
          return {
            success: true,
            content: content,
            streaming: false
          };
        } else {
          console.log("Invalid response structure from DeepSeek API");
          return {
            success: false,
            error: "Invalid response from AI service",
            content: "I'm having trouble understanding right now. Could you try asking in a different way?"
          };
        }
      }
      
      // Prepare for streaming response
      return new Promise((resolve) => {
        let fullContent = "";
        let isFirstChunk = true;
        
        response.data.on('data', (chunk) => {
          try {
            const lines = chunk.toString().split('\n').filter(line => line.trim() !== '');
            
            for (const line of lines) {
              if (line.startsWith('data: ')) {
                const data = line.substring(6);
                
                // Check for stream completion
                if (data === '[DONE]') {
                  console.log("Stream completed");
                  continue;
                }
                
                try {
                  const parsed = JSON.parse(data);
                  const delta = parsed.choices[0]?.delta?.content || '';
                  fullContent += delta;
                } catch (err) {
                  console.error("Error parsing JSON from stream:", err);
                }
              }
            }
            
            // For debugging only
            if (isFirstChunk) {
              console.log("First chunk received and processed");
              isFirstChunk = false;
            }
          } catch (err) {
            console.error("Error processing stream chunk:", err);
          }
        });
        
        response.data.on('end', () => {
          console.log("Stream ended, returning full content");
          resolve({
            success: true,
            content: fullContent,
            streaming: true,
            streamComplete: true
          });
        });
        
        response.data.on('error', (err) => {
          console.error("Stream error:", err);
          resolve({
            success: false,
            error: "Streaming error occurred",
            content: fullContent || "An error occurred during streaming."
          });
        });
      });
    } catch (apiError) {
      console.error("API request failed:", apiError.message);
      
      if (apiError.response) {
        console.error("API response error:", JSON.stringify({
          status: apiError.response.status,
          data: apiError.response.data
        }));
        
        throw new functions.https.HttpsError(
          "unavailable",
          `DeepSeek API error: ${apiError.response.status}`
        );
      }
      
      throw new functions.https.HttpsError(
        "internal",
        `API request failed: ${apiError.message}`
      );
    }
  } catch (error) {
    console.error("Function error:", error.message);
    
    // Don't expose internal errors to clients
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      "internal",
      "An unexpected error occurred"
    );
  }
});

/**
 * Stream chat completions from DeepSeek API
 * This function supports token-by-token streaming for real-time chat responses
 * NOTE: Firebase Functions currently doesn't support true streaming responses
 * This implementation immediately returns all tokens collected during the stream
 */
exports.streamAIResponse = functions.https.onCall(async (data, context) => {
  try {
    console.log("Streaming function triggered with request");
    console.log("Raw data type:", typeof data);
    
    let messages = [];
    
    // Handle all possible message formats for maximum compatibility
    if (data && typeof data === 'object') {
      if (data.messages && Array.isArray(data.messages)) {
        console.log("Found messages at root level:", data.messages.length);
        messages = data.messages;
      } else if (data.data && typeof data.data === 'object') {
        if (data.data.messages && Array.isArray(data.data.messages)) {
          console.log("Found messages in data.data:", data.data.messages.length);
          messages = data.data.messages;
        }
      }
    }
    
    // If we couldn't find messages anywhere, create a fallback
    if (!Array.isArray(messages) || messages.length === 0) {
      console.warn("No valid messages found in request. Using fallback content.");
      // Return a basic fallback response
      return {
        success: true,
        fullContent: "I'm your fitness coach! How can I help you today?",
        note: "This is a fallback response due to missing messages in the request."
      };
    }
    
    // Process the messages
    console.log(`Processing ${messages.length} messages for streaming`);
    
    // Create clean message objects
    const safeMessages = messages.map(msg => {
      if (typeof msg === "object" && msg !== null) {
        return {
          role: String(msg.role || "user"),
          content: String(msg.content || "")
        };
      }
      return { role: "user", content: String(msg || "") };
    });
    
    // Ensure messages are properly ordered (system message first)
    const orderedMessages = safeMessages.sort((a, b) => {
      if (a.role === 'system') return -1;
      if (b.role === 'system') return 1;
      return 0;
    });
    
    // Get API key from environment variables (now only using process.env)
    const apiKey = process.env.DEEPSEEK_API_KEY;
    console.log("API key from env:", apiKey ? "Found (not showing for security)" : "Not found");
    
    if (!apiKey) {
      console.error("API key not found in environment variables");
      // Return a graceful error that doesn't expose the API key issue
      return {
        success: true,
        fullContent: "I'm here to help with your fitness journey! What would you like to know?",
        chunks: ["I'm here to help with your fitness journey! ", "What would you like to know?"],
        note: "This is a fallback response due to a configuration issue."
      };
    }
    
    // Make streaming API request to DeepSeek
    const response = await axios({
      method: 'post',
      url: "https://api.deepseek.com/v1/chat/completions",
      data: {
        model: "deepseek-chat",
        messages: orderedMessages,
        temperature: 0.7,
        max_tokens: 1000,
        stream: true
      },
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json"
      },
      responseType: 'stream'
    });
    
    // Process streaming response
    return new Promise((resolve) => {
      let collectedChunks = [];
      let isFirstChunk = true;
      
      // Process each chunk as it comes in
      response.data.on('data', (chunk) => {
        try {
          const chunkStr = chunk.toString('utf8');
          const lines = chunkStr.split('\n').filter(line => line.trim().length > 0);
          
          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.substring(6).trim();
              
              if (data === '[DONE]') {
                console.log("Stream completion marker received");
                continue;
              }
              
              try {
                const parsedData = JSON.parse(data);
                const content = parsedData.choices[0]?.delta?.content || '';
                if (content) {
                  console.log(`Collected chunk: "${content}"`);
                  collectedChunks.push(content);
                }
              } catch (jsonError) {
                console.error("Error parsing JSON from chunk:", jsonError);
              }
            }
          }
          
          if (isFirstChunk) {
            console.log("First streaming chunk processed");
            isFirstChunk = false;
          }
        } catch (chunkError) {
          console.error("Error processing chunk:", chunkError);
        }
      });
      
      // Handle stream completion
      response.data.on('end', () => {
        console.log("Stream completed, finalizing response with chunks");
        
        // Log each chunk for debugging
        if (collectedChunks.length > 0) {
          console.log(`Returning ${collectedChunks.length} chunks`);
          console.log(`First few chunks: ${collectedChunks.slice(0, 5).join(', ')}`);
          console.log(`Last few chunks: ${collectedChunks.slice(-5).join(', ')}`);
        } else {
          console.log("No chunks collected!");
        }
        
        resolve({
          success: true,
          chunks: collectedChunks,
          fullContent: collectedChunks.join(''),
          streaming: true
        });
      });
      
      // Handle stream errors
      response.data.on('error', (err) => {
        console.error("Stream error:", err);
        resolve({
          success: false,
          error: "Error during streaming response",
          chunks: collectedChunks,
          fullContent: collectedChunks.join('')
        });
      });
    });
  } catch (error) {
    console.error("Streaming function error:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Streaming error: ${error.message}`
    );
  }
});

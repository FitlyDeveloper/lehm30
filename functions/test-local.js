const fs = require('fs');
const path = require('path');

// Create a simple test object with an image
const testPayload = {
  image: "TESTBASE64STRING" // Placeholder image data
};

// Write the test object to a file
console.log('Test payload:');
console.log(JSON.stringify(testPayload, null, 2));

// Test the image validation
if (!testPayload.image) {
  console.error('❌ Image validation failed - no image detected in payload');
} else {
  console.log('✅ Image validation passed - image detected in payload');
  console.log(`Image data length: ${testPayload.image.length} characters`);
}

// Test the JSON parsing
try {
  // Test JSON.stringify and parsing
  const stringified = JSON.stringify(testPayload);
  const parsed = JSON.parse(stringified);
  
  if (parsed.image === testPayload.image) {
    console.log('✅ JSON parsing test passed');
  } else {
    console.error('❌ JSON parsing test failed - image data changed during parse/stringify');
  }
} catch (error) {
  console.error('❌ JSON parsing test failed:', error);
}

// Create more realistic test with longer string
const longTestPayload = {
  image: "A".repeat(10000) // 10,000 character test string
};

console.log(`\nLong test payload image length: ${longTestPayload.image.length} characters`);

// Test JSON operation with long string
try {
  // Test JSON.stringify and parsing with longer data
  const stringified = JSON.stringify(longTestPayload);
  const parsed = JSON.parse(stringified);
  
  if (parsed.image === longTestPayload.image) {
    console.log('✅ Long JSON parsing test passed');
    console.log(`Parsed image length: ${parsed.image.length} characters`);
  } else {
    console.error('❌ Long JSON parsing test failed - image data changed during parse/stringify');
  }
} catch (error) {
  console.error('❌ Long JSON parsing test failed:', error);
}

console.log('\nTest complete - if all tests pass but you still have issues,');
console.log('the problem is likely in how the data is passed between client and function.'); 
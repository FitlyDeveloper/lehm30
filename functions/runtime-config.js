const fs = require('fs');

// Create runtime config object
const config = {
  "openai": {
    "api_key": "sk-example-replace-with-your-actual-key"
  }
};

// Write to file
fs.writeFileSync('.runtimeconfig.json', JSON.stringify(config, null, 2));
console.log('Runtime config created successfully!'); 
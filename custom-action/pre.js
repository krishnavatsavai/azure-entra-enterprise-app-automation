const core = require('@actions/core');
const winston = require('winston');

// Configure logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

async function pre() {
  try {
    logger.info('🚀 Starting Azure Entra Enterprise App Creator');
    logger.info('⚡ Pre-execution checks and setup...');

    // Environment validation
    const requiredInputs = [
      'config-file',
      'azure-tenant-id', 
      'azure-client-id',
      'azure-client-secret'
    ];

    const missingInputs = [];
    for (const input of requiredInputs) {
      if (!core.getInput(input)) {
        missingInputs.push(input);
      }
    }

    if (missingInputs.length > 0) {
      throw new Error(`Missing required inputs: ${missingInputs.join(', ')}`);
    }

    // Set environment variables for better error handling
    process.env.AZURE_ACTION_START_TIME = Date.now().toString();
    
    logger.info('✅ Pre-execution checks completed successfully');
    core.info('🔧 Environment validated, proceeding with enterprise app creation...');

  } catch (error) {
    logger.error('❌ Pre-execution failed', { error: error.message });
    core.setFailed(`Pre-execution failed: ${error.message}`);
    throw error;
  }
}

// Execute pre-checks
pre().catch(error => {
  process.exit(1);
});
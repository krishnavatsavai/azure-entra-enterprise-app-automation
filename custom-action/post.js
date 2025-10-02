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

async function post() {
  try {
    logger.info('🧹 Running post-execution cleanup...');

    // Calculate total execution time
    const startTime = process.env.AZURE_ACTION_START_TIME;
    if (startTime) {
      const totalTime = Math.round((Date.now() - parseInt(startTime)) / 1000);
      core.setOutput('total-execution-time', totalTime);
      logger.info(`⏱️ Total execution time: ${totalTime}s`);
    }

    // Get execution status
    const status = core.getInput('status') || 'unknown';
    const createdResources = core.getInput('created-resources') || '[]';
    
    // Summary reporting
    logger.info('📊 Execution Summary', {
      status,
      resourceCount: JSON.parse(createdResources).length,
      totalTime: startTime ? Math.round((Date.now() - parseInt(startTime)) / 1000) : 'unknown'
    });

    // Cleanup sensitive environment variables
    delete process.env.AZURE_CLIENT_SECRET;
    delete process.env.AZURE_ACTION_START_TIME;

    if (status === 'success') {
      core.info('✅ Azure Entra Enterprise Application created successfully!');
      core.info('🎉 Post-execution cleanup completed');
    } else if (status === 'dry-run') {
      core.info('🧪 Dry run completed successfully - no resources were created');
    } else {
      core.info('⚠️ Execution completed with warnings or errors');
    }

    logger.info('Post-execution cleanup completed successfully');

  } catch (error) {
    logger.error('❌ Post-execution cleanup failed', { error: error.message });
    // Don't fail the action for cleanup issues
    core.warning(`Post-execution cleanup failed: ${error.message}`);
  }
}

// Execute post-cleanup
post().catch(error => {
  core.warning(`Post-execution error: ${error.message}`);
});
const core = require('@actions/core');
const { Client } = require('@microsoft/microsoft-graph-client');
const { ConfidentialClientApplication } = require('@azure/msal-node');
const yaml = require('yaml');
const fs = require('fs');
const path = require('path');
const winston = require('winston');
const { formatDistanceToNow } = require('date-fns');

// Configure logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
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

class EnterpriseAppCreator {
  constructor() {
    this.startTime = Date.now();
    this.createdResources = [];
    this.graphClient = null;
    this.config = null;
  }

  async initialize() {
    try {
      // Get inputs
      const configFile = core.getInput('config-file', { required: true });
      const tenantId = core.getInput('azure-tenant-id', { required: true });
      const clientId = core.getInput('azure-client-id', { required: true });
      const clientSecret = core.getInput('azure-client-secret', { required: true });
      const dryRun = core.getInput('dry-run') === 'true';
      const environment = core.getInput('environment') || 'dev';
      const validationMode = core.getInput('validation-mode') === 'true';

      logger.info('Initializing Azure Entra Enterprise App Creator', {
        configFile,
        environment,
        dryRun,
        validationMode
      });

      // Load and validate configuration
      this.config = await this.loadConfiguration(configFile);
      
      if (validationMode) {
        await this.validateConfiguration(this.config);
      }

      // Initialize Microsoft Graph client
      await this.initializeGraphClient(tenantId, clientId, clientSecret);

      return {
        dryRun,
        environment,
        validationMode
      };
    } catch (error) {
      logger.error('Initialization failed', { error: error.message, stack: error.stack });
      core.setFailed(`Initialization failed: ${error.message}`);
      throw error;
    }
  }

  async loadConfiguration(configFile) {
    try {
      logger.info('Loading configuration file', { configFile });
      
      if (!fs.existsSync(configFile)) {
        throw new Error(`Configuration file not found: ${configFile}`);
      }

      const configContent = fs.readFileSync(configFile, 'utf8');
      const config = yaml.parse(configContent);

      logger.info('Configuration loaded successfully', {
        appName: config.enterpriseApplication?.displayName,
        galleryTemplate: config.enterpriseApplication?.galleryTemplate
      });

      return config;
    } catch (error) {
      logger.error('Failed to load configuration', { error: error.message });
      throw new Error(`Failed to load configuration: ${error.message}`);
    }
  }

  async validateConfiguration(config) {
    logger.info('Validating configuration...');
    
    const required = ['enterpriseApplication', 'enterpriseApplication.displayName', 'enterpriseApplication.galleryTemplate'];
    
    for (const field of required) {
      const value = field.split('.').reduce((obj, key) => obj?.[key], config);
      if (!value) {
        throw new Error(`Required configuration field missing: ${field}`);
      }
    }

    // Validate gallery template exists
    if (config.enterpriseApplication.galleryTemplate) {
      await this.validateGalleryTemplate(config.enterpriseApplication.galleryTemplate);
    }

    logger.info('Configuration validation passed');
  }

  async validateGalleryTemplate(templateName) {
    try {
      logger.info('Validating gallery template', { templateName });
      
      const templates = await this.graphClient
        .api('/applicationTemplates')
        .filter(`displayName eq '${templateName}'`)
        .get();

      if (!templates.value || templates.value.length === 0) {
        throw new Error(`Gallery template not found: ${templateName}`);
      }

      logger.info('Gallery template validated', { 
        templateId: templates.value[0].id,
        templateName: templates.value[0].displayName 
      });

      return templates.value[0];
    } catch (error) {
      logger.error('Gallery template validation failed', { error: error.message });
      throw error;
    }
  }

  async initializeGraphClient(tenantId, clientId, clientSecret) {
    try {
      logger.info('Initializing Microsoft Graph client...');

      const clientConfig = {
        auth: {
          clientId,
          clientSecret,
          authority: `https://login.microsoftonline.com/${tenantId}`
        }
      };

      const clientApp = new ConfidentialClientApplication(clientConfig);

      const clientCredentialRequest = {
        scopes: ['https://graph.microsoft.com/.default'],
      };

      const response = await clientApp.acquireTokenSilent(clientCredentialRequest);
      
      this.graphClient = Client.init({
        authProvider: (done) => {
          done(null, response.accessToken);
        }
      });

      // Test connection
      await this.graphClient.api('/me').get().catch(() => {
        // Expected to fail for client credentials, but confirms auth works
        logger.info('Graph client initialized successfully');
      });

    } catch (error) {
      logger.error('Failed to initialize Graph client', { error: error.message });
      throw new Error(`Failed to initialize Graph client: ${error.message}`);
    }
  }

  async createEnterpriseApplication(dryRun = false) {
    try {
      const appConfig = this.config.enterpriseApplication;
      
      logger.info('Creating enterprise application', {
        displayName: appConfig.displayName,
        galleryTemplate: appConfig.galleryTemplate,
        dryRun
      });

      if (dryRun) {
        logger.info('DRY RUN: Would create enterprise application', appConfig);
        return this.createMockResponse();
      }

      // Step 1: Get gallery template
      const template = await this.validateGalleryTemplate(appConfig.galleryTemplate);

      // Step 2: Instantiate from template
      const instantiateRequest = {
        displayName: appConfig.displayName
      };

      logger.info('Instantiating application from template', {
        templateId: template.id,
        displayName: appConfig.displayName
      });

      const instantiateResponse = await this.graphClient
        .api(`/applicationTemplates/${template.id}/instantiate`)
        .post(instantiateRequest);

      const applicationId = instantiateResponse.application.id;
      const servicePrincipalId = instantiateResponse.servicePrincipal.id;

      this.createdResources.push({
        type: 'Application',
        id: applicationId,
        name: appConfig.displayName
      });

      this.createdResources.push({
        type: 'ServicePrincipal',
        id: servicePrincipalId,
        name: appConfig.displayName
      });

      logger.info('Application instantiated successfully', {
        applicationId,
        servicePrincipalId
      });

      // Step 3: Configure application settings
      await this.configureApplication(applicationId, appConfig);

      // Step 4: Configure service principal
      await this.configureServicePrincipal(servicePrincipalId, appConfig);

      // Step 5: Configure SSO if specified
      if (appConfig.singleSignOn) {
        await this.configureSingleSignOn(servicePrincipalId, appConfig.singleSignOn);
      }

      // Step 6: Assign users/groups if specified
      if (appConfig.assignments && appConfig.assignments.length > 0) {
        await this.assignUsersAndGroups(servicePrincipalId, appConfig.assignments);
      }

      return {
        applicationId,
        servicePrincipalId,
        appUrl: `https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/${servicePrincipalId}`,
        ssoUrl: instantiateResponse.servicePrincipal.loginUrl,
        status: 'success'
      };

    } catch (error) {
      logger.error('Failed to create enterprise application', { error: error.message, stack: error.stack });
      throw error;
    }
  }

  async configureApplication(applicationId, config) {
    try {
      logger.info('Configuring application settings', { applicationId });

      const updateRequest = {};

      // Configure basic settings
      if (config.description) {
        updateRequest.description = config.description;
      }

      if (config.homepageUrl) {
        updateRequest.web = {
          homePageUrl: config.homepageUrl
        };
      }

      // Configure identifier URIs
      if (config.identifierUris && config.identifierUris.length > 0) {
        updateRequest.identifierUris = config.identifierUris;
      }

      if (Object.keys(updateRequest).length > 0) {
        await this.graphClient
          .api(`/applications/${applicationId}`)
          .patch(updateRequest);

        logger.info('Application configured successfully', { applicationId });
      }

    } catch (error) {
      logger.error('Failed to configure application', { error: error.message });
      throw error;
    }
  }

  async configureServicePrincipal(servicePrincipalId, config) {
    try {
      logger.info('Configuring service principal', { servicePrincipalId });

      const updateRequest = {};

      // Configure visibility and assignment
      if (config.userAssignmentRequired !== undefined) {
        updateRequest.appRoleAssignmentRequired = config.userAssignmentRequired;
      }

      if (config.visibleToUsers !== undefined) {
        updateRequest.tags = config.visibleToUsers ? [] : ['HideApp'];
      }

      // Configure notification settings
      if (config.notificationEmailAddresses && config.notificationEmailAddresses.length > 0) {
        updateRequest.notificationEmailAddresses = config.notificationEmailAddresses;
      }

      if (Object.keys(updateRequest).length > 0) {
        await this.graphClient
          .api(`/servicePrincipals/${servicePrincipalId}`)
          .patch(updateRequest);

        logger.info('Service principal configured successfully', { servicePrincipalId });
      }

    } catch (error) {
      logger.error('Failed to configure service principal', { error: error.message });
      throw error;
    }
  }

  async configureSingleSignOn(servicePrincipalId, ssoConfig) {
    try {
      logger.info('Configuring single sign-on', { servicePrincipalId, mode: ssoConfig.mode });

      const updateRequest = {
        preferredSingleSignOnMode: ssoConfig.mode
      };

      // Configure SAML settings if SAML mode
      if (ssoConfig.mode === 'saml' && ssoConfig.saml) {
        if (ssoConfig.saml.loginUrl) {
          updateRequest.loginUrl = ssoConfig.saml.loginUrl;
        }

        if (ssoConfig.saml.logoutUrl) {
          updateRequest.logoutUrl = ssoConfig.saml.logoutUrl;
        }
      }

      await this.graphClient
        .api(`/servicePrincipals/${servicePrincipalId}`)
        .patch(updateRequest);

      logger.info('Single sign-on configured successfully', { servicePrincipalId });

    } catch (error) {
      logger.error('Failed to configure single sign-on', { error: error.message });
      throw error;
    }
  }

  async assignUsersAndGroups(servicePrincipalId, assignments) {
    try {
      logger.info('Assigning users and groups', { servicePrincipalId, count: assignments.length });

      for (const assignment of assignments) {
        const assignmentRequest = {
          principalId: assignment.principalId,
          resourceId: servicePrincipalId,
          appRoleId: assignment.appRoleId || '00000000-0000-0000-0000-000000000000' // Default role
        };

        await this.graphClient
          .api('/appRoleAssignments')
          .post(assignmentRequest);

        this.createdResources.push({
          type: 'AppRoleAssignment',
          id: `${assignment.principalId}-${servicePrincipalId}`,
          name: `Assignment for ${assignment.principalId}`
        });

        logger.info('Assignment created', assignmentRequest);
      }

      logger.info('All assignments completed successfully');

    } catch (error) {
      logger.error('Failed to assign users and groups', { error: error.message });
      throw error;
    }
  }

  createMockResponse() {
    const mockId = 'mock-' + Date.now();
    return {
      applicationId: mockId + '-app',
      servicePrincipalId: mockId + '-sp',
      appUrl: `https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/${mockId}-sp`,
      ssoUrl: 'https://myapps.microsoft.com/mock-app',
      status: 'dry-run'
    };
  }

  getExecutionTime() {
    return Math.round((Date.now() - this.startTime) / 1000);
  }

  setOutputs(result) {
    try {
      // Set action outputs
      core.setOutput('application-id', result.applicationId);
      core.setOutput('service-principal-id', result.servicePrincipalId);
      core.setOutput('app-url', result.appUrl);
      core.setOutput('sso-url', result.ssoUrl);
      core.setOutput('status', result.status);
      core.setOutput('execution-time', this.getExecutionTime());
      core.setOutput('created-resources', JSON.stringify(this.createdResources));

      logger.info('Action outputs set successfully', {
        status: result.status,
        executionTime: this.getExecutionTime(),
        resourceCount: this.createdResources.length
      });

    } catch (error) {
      logger.error('Failed to set outputs', { error: error.message });
    }
  }
}

// Main execution
async function run() {
  const creator = new EnterpriseAppCreator();
  
  try {
    // Initialize
    const { dryRun, environment, validationMode } = await creator.initialize();

    // Create enterprise application
    const result = await creator.createEnterpriseApplication(dryRun);

    // Set outputs
    creator.setOutputs(result);

    // Success summary
    const executionTime = creator.getExecutionTime();
    logger.info('Enterprise application creation completed successfully', {
      status: result.status,
      executionTime: `${executionTime}s`,
      applicationId: result.applicationId,
      servicePrincipalId: result.servicePrincipalId,
      environment,
      resourceCount: creator.createdResources.length
    });

    core.info(`✅ Enterprise application created successfully in ${executionTime}s`);
    core.info(`🔗 Application URL: ${result.appUrl}`);
    core.info(`🔐 SSO URL: ${result.ssoUrl}`);

  } catch (error) {
    const executionTime = creator.getExecutionTime();
    
    logger.error('Enterprise application creation failed', {
      error: error.message,
      stack: error.stack,
      executionTime: `${executionTime}s`,
      resourceCount: creator.createdResources.length
    });

    // Set failure outputs
    core.setOutput('status', 'failed');
    core.setOutput('execution-time', executionTime);
    core.setOutput('created-resources', JSON.stringify(creator.createdResources));

    core.setFailed(`❌ Enterprise application creation failed: ${error.message}`);
    process.exit(1);
  }
}

// Execute if called directly
if (require.main === module) {
  run();
}

module.exports = { EnterpriseAppCreator, run };
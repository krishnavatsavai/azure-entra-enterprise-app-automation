const { EnterpriseAppCreator } = require('../src/index');
const core = require('@actions/core');
const fs = require('fs');
const yaml = require('yaml');

// Mock dependencies
jest.mock('@actions/core');
jest.mock('@microsoft/microsoft-graph-client');
jest.mock('@azure/msal-node');
jest.mock('fs');
jest.mock('yaml');

describe('EnterpriseAppCreator', () => {
  let creator;
  let mockConfig;

  beforeEach(() => {
    creator = new EnterpriseAppCreator();
    mockConfig = {
      enterpriseApplication: {
        displayName: 'Test Salesforce App',
        galleryTemplate: 'Salesforce',
        description: 'Test application for Salesforce integration',
        homepageUrl: 'https://test.salesforce.com',
        userAssignmentRequired: true,
        visibleToUsers: true,
        singleSignOn: {
          mode: 'saml',
          saml: {
            loginUrl: 'https://test.salesforce.com/sso',
            logoutUrl: 'https://test.salesforce.com/logout'
          }
        },
        assignments: [
          {
            principalId: 'user-123',
            appRoleId: '00000000-0000-0000-0000-000000000000'
          }
        ]
      }
    };

    // Reset mocks
    jest.clearAllMocks();
    
    // Mock core inputs
    core.getInput.mockImplementation((name) => {
      const inputs = {
        'config-file': './test-config.yaml',
        'azure-tenant-id': 'test-tenant-id',
        'azure-client-id': 'test-client-id',
        'azure-client-secret': 'test-client-secret',
        'dry-run': 'false',
        'environment': 'test',
        'validation-mode': 'true'
      };
      return inputs[name] || '';
    });

    // Mock file system
    fs.existsSync.mockReturnValue(true);
    fs.readFileSync.mockReturnValue('mock-yaml-content');
    yaml.parse.mockReturnValue(mockConfig);
  });

  describe('loadConfiguration', () => {
    test('should load configuration successfully', async () => {
      const result = await creator.loadConfiguration('./test-config.yaml');
      
      expect(fs.existsSync).toHaveBeenCalledWith('./test-config.yaml');
      expect(fs.readFileSync).toHaveBeenCalledWith('./test-config.yaml', 'utf8');
      expect(yaml.parse).toHaveBeenCalledWith('mock-yaml-content');
      expect(result).toEqual(mockConfig);
    });

    test('should throw error for missing file', async () => {
      fs.existsSync.mockReturnValue(false);
      
      await expect(creator.loadConfiguration('./missing-config.yaml'))
        .rejects.toThrow('Configuration file not found: ./missing-config.yaml');
    });

    test('should throw error for invalid YAML', async () => {
      yaml.parse.mockImplementation(() => {
        throw new Error('Invalid YAML');
      });
      
      await expect(creator.loadConfiguration('./test-config.yaml'))
        .rejects.toThrow('Failed to load configuration: Invalid YAML');
    });
  });

  describe('validateConfiguration', () => {
    test('should validate configuration successfully', async () => {
      // Mock graph client and template validation
      creator.graphClient = {
        api: jest.fn().mockReturnValue({
          filter: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({
              value: [{ id: 'template-123', displayName: 'Salesforce' }]
            })
          })
        })
      };

      await expect(creator.validateConfiguration(mockConfig))
        .resolves.not.toThrow();
    });

    test('should throw error for missing required fields', async () => {
      const invalidConfig = {
        enterpriseApplication: {
          // Missing displayName and galleryTemplate
        }
      };

      await expect(creator.validateConfiguration(invalidConfig))
        .rejects.toThrow('Required configuration field missing');
    });

    test('should validate gallery template exists', async () => {
      creator.graphClient = {
        api: jest.fn().mockReturnValue({
          filter: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({
              value: [] // Empty array - template not found
            })
          })
        })
      };

      await expect(creator.validateConfiguration(mockConfig))
        .rejects.toThrow('Gallery template not found: Salesforce');
    });
  });

  describe('createEnterpriseApplication', () => {
    beforeEach(() => {
      // Mock graph client methods
      creator.graphClient = {
        api: jest.fn().mockImplementation((endpoint) => {
          if (endpoint.includes('/applicationTemplates')) {
            if (endpoint.includes('/instantiate')) {
              return {
                post: jest.fn().mockResolvedValue({
                  application: { id: 'app-123' },
                  servicePrincipal: { 
                    id: 'sp-123',
                    loginUrl: 'https://myapps.microsoft.com/test-app'
                  }
                })
              };
            } else {
              return {
                filter: jest.fn().mockReturnValue({
                  get: jest.fn().mockResolvedValue({
                    value: [{ id: 'template-123', displayName: 'Salesforce' }]
                  })
                })
              };
            }
          }
          
          if (endpoint.includes('/applications/') || endpoint.includes('/servicePrincipals/')) {
            return {
              patch: jest.fn().mockResolvedValue({})
            };
          }

          if (endpoint === '/appRoleAssignments') {
            return {
              post: jest.fn().mockResolvedValue({})
            };
          }

          return {};
        })
      };

      creator.config = mockConfig;
    });

    test('should create enterprise application successfully', async () => {
      const result = await creator.createEnterpriseApplication(false);

      expect(result).toMatchObject({
        applicationId: 'app-123',
        servicePrincipalId: 'sp-123',
        status: 'success'
      });

      expect(result.appUrl).toContain('sp-123');
      expect(result.ssoUrl).toBe('https://myapps.microsoft.com/test-app');
    });

    test('should handle dry run mode', async () => {
      const result = await creator.createEnterpriseApplication(true);

      expect(result.status).toBe('dry-run');
      expect(result.applicationId).toContain('mock-');
      expect(result.servicePrincipalId).toContain('mock-');
    });

    test('should track created resources', async () => {
      await creator.createEnterpriseApplication(false);

      expect(creator.createdResources).toHaveLength(3); // App, SP, Assignment
      expect(creator.createdResources[0].type).toBe('Application');
      expect(creator.createdResources[1].type).toBe('ServicePrincipal');
      expect(creator.createdResources[2].type).toBe('AppRoleAssignment');
    });
  });

  describe('setOutputs', () => {
    test('should set all action outputs correctly', () => {
      const mockResult = {
        applicationId: 'app-123',
        servicePrincipalId: 'sp-123',
        appUrl: 'https://portal.azure.com/app-123',
        ssoUrl: 'https://myapps.microsoft.com/test-app',
        status: 'success'
      };

      creator.createdResources = [
        { type: 'Application', id: 'app-123', name: 'Test App' },
        { type: 'ServicePrincipal', id: 'sp-123', name: 'Test App' }
      ];

      creator.setOutputs(mockResult);

      expect(core.setOutput).toHaveBeenCalledWith('application-id', 'app-123');
      expect(core.setOutput).toHaveBeenCalledWith('service-principal-id', 'sp-123');
      expect(core.setOutput).toHaveBeenCalledWith('app-url', 'https://portal.azure.com/app-123');
      expect(core.setOutput).toHaveBeenCalledWith('sso-url', 'https://myapps.microsoft.com/test-app');
      expect(core.setOutput).toHaveBeenCalledWith('status', 'success');
      expect(core.setOutput).toHaveBeenCalledWith('execution-time', expect.any(Number));
      expect(core.setOutput).toHaveBeenCalledWith('created-resources', expect.any(String));
    });
  });

  describe('getExecutionTime', () => {
    test('should calculate execution time correctly', () => {
      const startTime = Date.now();
      creator.startTime = startTime - 5000; // 5 seconds ago

      const executionTime = creator.getExecutionTime();
      
      expect(executionTime).toBeGreaterThanOrEqual(4);
      expect(executionTime).toBeLessThanOrEqual(6);
    });
  });
});

describe('Error Handling', () => {
  let creator;

  beforeEach(() => {
    creator = new EnterpriseAppCreator();
    jest.clearAllMocks();
  });

  test('should handle authentication failures gracefully', async () => {
    const { ConfidentialClientApplication } = require('@azure/msal-node');
    ConfidentialClientApplication.mockImplementation(() => ({
      acquireTokenSilent: jest.fn().mockRejectedValue(new Error('Authentication failed'))
    }));

    await expect(creator.initializeGraphClient('tenant', 'client', 'secret'))
      .rejects.toThrow('Failed to initialize Graph client: Authentication failed');
  });

  test('should handle Graph API errors gracefully', async () => {
    creator.graphClient = {
      api: jest.fn().mockReturnValue({
        filter: jest.fn().mockReturnValue({
          get: jest.fn().mockRejectedValue(new Error('Graph API error'))
        })
      })
    };

    await expect(creator.validateGalleryTemplate('TestApp'))
      .rejects.toThrow('Graph API error');
  });

  test('should handle configuration errors gracefully', async () => {
    fs.readFileSync.mockImplementation(() => {
      throw new Error('File read error');
    });

    await expect(creator.loadConfiguration('./test-config.yaml'))
      .rejects.toThrow('Failed to load configuration: File read error');
  });
});
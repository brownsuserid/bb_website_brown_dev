/**
 * Configuration for bb-web-home infrastructure
 * 
 * Uses plain strings to avoid CloudFormation exports and cross-stack dependencies.
 * Following CDK best practices from infrastructure quality skill.
 */

export interface SiteConfig {
    /** Domain names to serve the site from */
    domains: string[];

    /** Existing Route53 hosted zone IDs (plain strings, not constructs) */
    hostedZoneIds: {
        [domain: string]: string;
    };

    /** Optional: Existing ACM certificate ARN to reuse */
    certificateArn?: string;

    /** Environment name for resource tagging */
    environment: string;
}

/**
 * Production configuration
 *
 * Hosted Zones:
 * - brainbridge.app: Z0886717BPNWIHS2PKZD (existing)
 * - brainbridgelabs.ai: Will be created by CDK
 *
 * Note: www subdomains use the same hosted zone as their parent domain
 */
export const PROD_CONFIG: SiteConfig = {
    domains: [
        'brainbridge.app',
        'www.brainbridge.app',
        'brainbridgelabs.ai',
        'www.brainbridgelabs.ai',
    ],
    hostedZoneIds: {
        'brainbridge.app': 'Z0886717BPNWIHS2PKZD',  // Existing hosted zone
        'www.brainbridge.app': 'Z0886717BPNWIHS2PKZD',  // Same zone as parent
        // brainbridgelabs.ai zone will be created by CDK
        // www.brainbridgelabs.ai will use the same zone (handled in stack)
    },
    environment: 'prod',
    // certificateArn will be created by CDK on first deployment
};

/**
 * Development configuration
 */
export const DEV_CONFIG: SiteConfig = {
    domains: ['dev.brainbridge.app'],
    hostedZoneIds: {
        'dev.brainbridge.app': 'Z0886717BPNWIHS2PKZD',  // Use parent zone for subdomain
    },
    environment: 'dev',
};

/**
 * Get configuration for environment
 */
export function getConfig(env: string): SiteConfig {
    switch (env.toLowerCase()) {
        case 'prod':
        case 'production':
            return PROD_CONFIG;
        case 'dev':
        case 'development':
            return DEV_CONFIG;
        default:
            throw new Error(`Unknown environment: ${env}`);
    }
}

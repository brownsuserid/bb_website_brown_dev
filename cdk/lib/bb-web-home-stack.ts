import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as targets from 'aws-cdk-lib/aws-route53-targets';
import { Construct } from 'constructs';
import { SiteConfig } from './config';

export interface BBWebHomeStackProps extends cdk.StackProps {
    config: SiteConfig;
}

/**
 * CDK Stack for bb-web-home static site hosting
 * 
 * Architecture:
 * - S3 bucket for static assets (private)
 * - CloudFront distribution with OAC
 * - ACM certificate for SSL/TLS
 * - Route53 DNS records for both domains
 * 
 * Following CDK best practices:
 * - No cross-stack dependencies
 * - Uses plain strings for existing resources
 * - Single stack for all resources
 */
export class BBWebHomeStack extends cdk.Stack {
    constructor(scope: Construct, id: string, props: BBWebHomeStackProps) {
        super(scope, id, props);

        const { config } = props;

        // ========================================
        // S3 Bucket for Static Site Hosting
        // ========================================

        const siteBucket = new s3.Bucket(this, 'SiteBucket', {
            bucketName: `bb-web-home-${config.environment}-${this.account}`,
            encryption: s3.BucketEncryption.S3_MANAGED,
            blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
            enforceSSL: true,  // Require SSL/TLS for all requests
            removalPolicy: config.environment === 'prod'
                ? cdk.RemovalPolicy.RETAIN
                : cdk.RemovalPolicy.DESTROY,
            autoDeleteObjects: config.environment !== 'prod',
            versioned: true,
            lifecycleRules: [
                {
                    noncurrentVersionExpiration: cdk.Duration.days(30),
                },
            ],
        });

        // ========================================
        // Route53 Hosted Zones
        // ========================================

        const hostedZones: { [domain: string]: route53.IHostedZone } = {};

        // Import or create hosted zones for each domain
        for (const domain of config.domains) {
            if (config.hostedZoneIds[domain]) {
                // Import existing hosted zone using plain string ID
                hostedZones[domain] = route53.HostedZone.fromHostedZoneAttributes(
                    this,
                    `HostedZone-${domain.replace(/\./g, '-')}`,
                    {
                        hostedZoneId: config.hostedZoneIds[domain],
                        zoneName: domain,
                    }
                );
            } else {
                // Create new hosted zone (e.g., for brainbridgelabs.ai)
                hostedZones[domain] = new route53.HostedZone(
                    this,
                    `HostedZone-${domain.replace(/\./g, '-')}`,
                    {
                        zoneName: domain,
                        comment: `Hosted zone for ${domain} (bb-web-home)`,
                    }
                );
            }
        }

        // ========================================
        // ACM Certificate (must be in us-east-1 for CloudFront)
        // ========================================

        const certificate = new acm.Certificate(this, 'Certificate', {
            domainName: config.domains[0],  // Primary domain
            subjectAlternativeNames: config.domains.slice(1),  // Additional domains
            validation: acm.CertificateValidation.fromDnsMultiZone(hostedZones),
        });

        // ========================================
        // CloudFront Distribution
        // ========================================

        // Origin Access Control for S3
        const oac = new cloudfront.S3OriginAccessControl(this, 'OAC', {
            signing: cloudfront.Signing.SIGV4_NO_OVERRIDE,
        });

        const distribution = new cloudfront.Distribution(this, 'Distribution', {
            defaultBehavior: {
                origin: origins.S3BucketOrigin.withOriginAccessControl(siteBucket, {
                    originAccessControl: oac,
                }),
                viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
                cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
                compress: true,
            },
            domainNames: config.domains,
            certificate: certificate,
            minimumProtocolVersion: cloudfront.SecurityPolicyProtocol.TLS_V1_2_2021,
            httpVersion: cloudfront.HttpVersion.HTTP2_AND_3,
            priceClass: cloudfront.PriceClass.PRICE_CLASS_100,  // North America & Europe
            defaultRootObject: 'index.html',
            errorResponses: [
                {
                    httpStatus: 404,
                    responseHttpStatus: 200,
                    responsePagePath: '/index.html',
                    ttl: cdk.Duration.minutes(5),
                },
                {
                    httpStatus: 403,
                    responseHttpStatus: 200,
                    responsePagePath: '/index.html',
                    ttl: cdk.Duration.minutes(5),
                },
            ],
            comment: `bb-web-home ${config.environment}`,
        });

        // ========================================
        // Route53 DNS Records
        // ========================================

        for (const domain of config.domains) {
            const zone = hostedZones[domain];

            // A record (IPv4)
            new route53.ARecord(this, `ARecord-${domain.replace(/\./g, '-')}`, {
                zone: zone,
                recordName: domain,
                target: route53.RecordTarget.fromAlias(
                    new targets.CloudFrontTarget(distribution)
                ),
                comment: `bb-web-home ${config.environment} - IPv4`,
            });

            // AAAA record (IPv6)
            new route53.AaaaRecord(this, `AAAARecord-${domain.replace(/\./g, '-')}`, {
                zone: zone,
                recordName: domain,
                target: route53.RecordTarget.fromAlias(
                    new targets.CloudFrontTarget(distribution)
                ),
                comment: `bb-web-home ${config.environment} - IPv6`,
            });
        }

        // ========================================
        // Stack Outputs
        // ========================================

        new cdk.CfnOutput(this, 'BucketName', {
            value: siteBucket.bucketName,
            description: 'S3 bucket name for deployment',
            exportName: undefined,  // Explicitly no export
        });

        new cdk.CfnOutput(this, 'DistributionId', {
            value: distribution.distributionId,
            description: 'CloudFront distribution ID for cache invalidation',
            exportName: undefined,  // Explicitly no export
        });

        new cdk.CfnOutput(this, 'DistributionDomainName', {
            value: distribution.distributionDomainName,
            description: 'CloudFront distribution domain name',
            exportName: undefined,  // Explicitly no export
        });

        new cdk.CfnOutput(this, 'CertificateArn', {
            value: certificate.certificateArn,
            description: 'ACM certificate ARN',
            exportName: undefined,  // Explicitly no export
        });

        // Output nameservers for newly created hosted zones
        for (const domain of config.domains) {
            if (!config.hostedZoneIds[domain]) {
                const zone = hostedZones[domain] as route53.HostedZone;
                new cdk.CfnOutput(this, `NameServers-${domain.replace(/\./g, '-')}`, {
                    value: cdk.Fn.join(', ', zone.hostedZoneNameServers || []),
                    description: `Nameservers for ${domain} - update at your registrar`,
                    exportName: undefined,  // Explicitly no export
                });
            }
        }

        // ========================================
        // Tags
        // ========================================

        cdk.Tags.of(this).add('Project', 'bb-web-home');
        cdk.Tags.of(this).add('Environment', config.environment);
        cdk.Tags.of(this).add('ManagedBy', 'CDK');
    }
}

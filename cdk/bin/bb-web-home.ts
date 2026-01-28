#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Aspects } from 'aws-cdk-lib';
import { AwsSolutionsChecks, NagSuppressions } from 'cdk-nag';
import { BBWebHomeStack } from '../lib/bb-web-home-stack';
import { getConfig } from '../lib/config';

const app = new cdk.App();

// Get environment from context or default to dev
const environment = app.node.tryGetContext('environment') || 'prod';
const config = getConfig(environment);

// Create stack
const stack = new BBWebHomeStack(app, `BBWebHome${config.environment.charAt(0).toUpperCase() + config.environment.slice(1)}Stack`, {
    config,
    env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: 'us-east-1',  // Required for CloudFront + ACM
    },
    description: `bb-web-home static site infrastructure (${config.environment})`,
    terminationProtection: config.environment === 'prod',
});

// Add cdk-nag security checks
Aspects.of(app).add(new AwsSolutionsChecks({ verbose: true }));

// Suppress specific cdk-nag rules that don't apply to static sites
const suppressions = [
    {
        id: 'AwsSolutions-S1',
        reason: 'S3 server access logging not required for static site bucket',
    },
    {
        id: 'AwsSolutions-CFR1',
        reason: 'CloudFront geo restriction not required for public website',
    },
    {
        id: 'AwsSolutions-CFR2',
        reason: 'WAF not required for static website (no dynamic content)',
    },
    {
        id: 'AwsSolutions-CFR3',
        reason: 'CloudFront access logging not required for static website (cost optimization)',
    },
    {
        id: 'AwsSolutions-CFR4',
        reason: 'Using TLS 1.2 minimum (TLS_V1_2_2021 security policy)',
    },
];

suppressions.forEach(({ id, reason }) => {
    NagSuppressions.addStackSuppressions(stack, [{ id, reason }]);
});

app.synth();

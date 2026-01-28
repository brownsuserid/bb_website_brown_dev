# Brain Bridge Web Home

Marketing website for Brain Bridge, deployed to **brainbridge.app** and **brainbridgelabs.ai**.

A modern, visually stunning static site built with Astro and deployed to AWS infrastructure.

## Technology Stack

- **Framework**: [Astro](https://astro.build/) 5.x (Static Site Generation)
- **Styling**: [Tailwind CSS](https://tailwindcss.com/) v4.1 with custom design system
- **3D Graphics**: [Three.js](https://threejs.org/) for interactive visual elements
- **Animations**: [Lottie](https://lottiefiles.com/) for high-quality animations
- **Carousel**: [Swiper](https://swiperjs.com/) for image galleries
- **Typography**: Inter and Inter Display fonts (self-hosted)
- **Infrastructure**: AWS CDK (TypeScript) for cloud deployment

## Local Development

All commands are run from the root of the project:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Installs dependencies                            |
| `npm run dev`             | Starts local dev server at `localhost:4321`      |
| `npm run build`           | Build your production site to `./dist/`          |
| `npm run preview`         | Preview your build locally, before deploying     |
| `npm run astro ...`       | Run CLI commands like `astro add`, `astro check` |
| `npm run astro -- --help` | Get help using the Astro CLI                     |

### Development Server

The dev server runs with `--host` flag enabled, making it accessible on your local network:

```bash
npm run dev
# Server will be available at:
# - http://localhost:4321
# - http://[your-local-ip]:4321
```

## Deployment

### Prerequisites

- **AWS CLI** configured with appropriate credentials
- **Node.js** 18+ and npm
- **AWS CDK** (installed automatically via npx, or install globally: `npm install -g aws-cdk`)
- **AWS Account** with permissions for S3, CloudFront, ACM, and Route53

### Initial Setup

1. **Install project dependencies:**
   ```bash
   npm install
   ```

2. **Install CDK dependencies:**
   ```bash
   cd cdk
   npm install
   cd ..
   ```

3. **Bootstrap CDK (first time only):**
   ```bash
   cd cdk
   npx cdk bootstrap aws://ACCOUNT-ID/us-east-1
   cd ..
   ```
   
   Replace `ACCOUNT-ID` with your AWS account ID. This only needs to be done once per AWS account/region.

### Deploy to Development

Deploy to the development environment (`dev.brainbridge.app`):

```bash
./scripts/deploy.sh dev
```

**What happens:**
1. ✅ Builds the Astro site (`npm run build`)
2. ✅ Deploys CDK infrastructure (creates/updates CloudFormation stack)
3. ✅ Syncs built assets to S3 with optimized caching headers
4. ✅ Invalidates CloudFront cache for immediate updates
5. ✅ Displays deployment summary with URLs

**Note:** Development deployments run **without confirmation** for faster iteration.

### Deploy to Production

Deploy to production (`brainbridge.app` and `brainbridgelabs.ai`):

```bash
./scripts/deploy.sh prod
```

**What happens:**
1. ⚠️  Prompts for confirmation (safety check)
2. ✅ Builds the Astro site
3. ✅ Deploys CDK infrastructure to production
4. ✅ Syncs assets to S3 with long-term caching for static assets
5. ✅ Invalidates CloudFront cache globally
6. ✅ Displays deployment URLs and nameserver information (if applicable)

**Note:** Production deployments require **manual confirmation** (y/N prompt) to prevent accidental deployments.

### Deployment Script Details

The `deploy.sh` script is a unified, automated deployment pipeline that:

- **Auto-detects** CDK command (npx/yarn/pnpm)
- **Validates** environment (dev/prod only)
- **Builds** the Astro site using `scripts/build.sh`
- **Deploys** infrastructure using CDK with environment-specific stack names
- **Extracts** CloudFormation outputs (bucket name, distribution ID)
- **Syncs** assets with optimized caching strategies:
  - Static assets (JS, CSS, images): 1-year cache (`max-age=31536000, immutable`)
  - HTML files: No cache (`no-cache, no-store, must-revalidate`)
- **Invalidates** CloudFront cache for immediate content updates
- **Displays** deployment summary with actionable information

### Caching Strategy

The deployment script implements a sophisticated caching strategy:

- **Static Assets** (CSS, JS, images, fonts): Cached for 1 year with `immutable` flag
  - These files have content-based hashes in their filenames
  - Safe to cache indefinitely
- **HTML Files**: Never cached
  - Always fetched fresh from origin
  - Ensures users get the latest content immediately

This strategy maximizes performance while ensuring content freshness.

## DNS Configuration

### For brainbridge.app
✅ **Already configured** in Route53 (Hosted Zone ID: `Z0886717BPNWIHS2PKZD`)

No action needed - DNS records are automatically created/updated during deployment.

### For brainbridgelabs.ai
⚠️ **Requires manual nameserver configuration** at your domain registrar.

After the **first production deployment**, follow these steps:

1. **Deploy to production:**
   ```bash
   ./scripts/deploy.sh prod
   ```

2. **Copy nameserver records** from the deployment output:
   ```
   NameServers-brainbridgelabs-ai:
     ns-1234.awsdns-12.org, ns-5678.awsdns-56.com, ...
   ```

3. **Update nameservers** at your domain registrar (GoDaddy, Namecheap, etc.)
   - Log into your registrar's control panel
   - Find DNS/Nameserver settings for `brainbridgelabs.ai`
   - Replace existing nameservers with the AWS nameservers from step 2

4. **Wait for DNS propagation** (typically 24-48 hours)
   - Check status: `dig brainbridgelabs.ai`
   - Use online tools: [whatsmydns.net](https://www.whatsmydns.net/)

5. **SSL certificate auto-validates** via DNS once propagation completes
   - ACM automatically creates DNS validation records in Route53
   - No manual intervention required

## Infrastructure Architecture

### AWS Resources

The CDK stack (`BBWebHomeStack`) creates and manages:

- **S3 Bucket**: Private bucket for static assets
  - Server-side encryption (SSE-S3)
  - Versioning enabled
  - Public access blocked
  - SSL/TLS enforced
  - Lifecycle policy: Delete old versions after 30 days
  - Retention: RETAIN (prod), DESTROY (dev)

- **CloudFront Distribution**: Global CDN
  - Origin Access Control (OAC) for secure S3 access
  - HTTPS redirect enforced
  - HTTP/2 and HTTP/3 enabled
  - TLS 1.2+ minimum
  - Optimized caching policy
  - Gzip/Brotli compression
  - Custom error pages (404/403 → index.html for SPA routing)
  - Price class: North America & Europe

- **ACM Certificate**: SSL/TLS certificate
  - Multi-domain (SAN) certificate
  - Primary: `brainbridge.app`
  - Alternative: `brainbridgelabs.ai`
  - Auto-renewal enabled
  - DNS validation via Route53

- **Route53 Hosted Zones**:
  - `brainbridge.app`: Existing zone (imported)
  - `brainbridgelabs.ai`: Created by CDK (new zone)

- **Route53 DNS Records**: A and AAAA records for both domains
  - IPv4 (A) and IPv6 (AAAA) support
  - Alias records pointing to CloudFront distribution

### CDK Best Practices

This stack follows production-grade CDK patterns:

- ✅ **No CloudFormation exports** - Avoids cross-stack dependency locks
- ✅ **Plain string references** - Uses hosted zone IDs as strings, not constructs
- ✅ **Single stack architecture** - All resources in one stack for simplicity
- ✅ **Environment-specific configuration** - Separate configs for dev/prod
- ✅ **Explicit removal policies** - RETAIN for prod, DESTROY for dev
- ✅ **Origin Access Control (OAC)** - Modern replacement for OAI
- ✅ **Security hardening** - SSL enforcement, private buckets, TLS 1.2+

### Stack Outputs

The CDK stack provides these outputs (used by `deploy.sh`):

- `BucketName`: S3 bucket name for asset deployment
- `DistributionId`: CloudFront distribution ID for cache invalidation
- `DistributionDomainName`: CloudFront domain (e.g., `d1234abcd.cloudfront.net`)
- `CertificateArn`: ACM certificate ARN
- `NameServers-brainbridgelabs-ai`: Nameservers for new hosted zone (if created)

## Project Structure

```
bb-web-home/
├── cdk/                           # AWS CDK infrastructure (TypeScript)
│   ├── bin/
│   │   └── bb-web-home.ts         # CDK app entry point
│   ├── lib/
│   │   ├── bb-web-home-stack.ts   # Main stack definition
│   │   └── config.ts              # Environment configurations
│   ├── cdk.json                   # CDK configuration
│   ├── tsconfig.json              # TypeScript config
│   └── package.json               # CDK dependencies
│
├── scripts/                       # Deployment automation
│   ├── build.sh                   # Builds Astro site
│   └── deploy.sh                  # Unified deployment pipeline
│
├── src/                           # Astro source code
│   ├── assets/                    # Static assets (fonts, images, etc.)
│   │   └── fonts/                 # Self-hosted Inter fonts
│   ├── components/                # Reusable Astro components
│   ├── data/                      # Content data files
│   ├── layouts/                   # Page layouts
│   └── pages/                     # Site pages (routes)
│
├── public/                        # Public static assets (copied as-is)
│
├── dist/                          # Build output (generated by Astro)
│
├── astro.config.mjs               # Astro configuration
├── package.json                   # Project dependencies
└── README.md                      # This file
```

### Key Files

- **`astro.config.mjs`**: Astro configuration with Tailwind CSS v4 integration and local font definitions
- **`cdk/lib/config.ts`**: Environment-specific infrastructure configuration (domains, hosted zones)
- **`cdk/lib/bb-web-home-stack.ts`**: Complete CDK stack definition for all AWS resources
- **`scripts/deploy.sh`**: Automated deployment pipeline (build → deploy → sync → invalidate)
- **`scripts/build.sh`**: Astro build script with validation

## Troubleshooting

### CDK Deployment Fails

**Check TypeScript compilation:**
```bash
cd cdk
npm run build
```

**Validate CloudFormation templates:**
```bash
cd cdk
npx cdk synth
```

**Verify AWS credentials:**
```bash
aws sts get-caller-identity
```

**Check CDK bootstrap:**
```bash
cd cdk
npx cdk bootstrap aws://$(aws sts get-caller-identity --query Account --output text)/us-east-1
```

### Site Not Updating After Deployment

**Cause:** CloudFront cache invalidation takes 1-5 minutes to propagate globally.

**Check invalidation status:**
```bash
# Get distribution ID from deployment output or:
DIST_ID=$(aws cloudformation describe-stacks --stack-name BBWebHomeProdStack --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" --output text)

# List recent invalidations
aws cloudfront list-invalidations --distribution-id $DIST_ID

# Check specific invalidation status
aws cloudfront get-invalidation --distribution-id $DIST_ID --id INVALIDATION_ID
```

**Force browser cache clear:**
- Hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
- Clear browser cache completely

### DNS Not Resolving

**Check DNS propagation:**
```bash
# Check A record
dig brainbridge.app

# Check AAAA record (IPv6)
dig brainbridgelabs.ai AAAA

# Check nameservers
dig brainbridgelabs.ai NS
```

**Online DNS propagation checker:**
- [whatsmydns.net](https://www.whatsmydns.net/)
- [dnschecker.org](https://dnschecker.org/)

**Common issues:**
- Nameservers not updated at registrar (for `brainbridgelabs.ai`)
- DNS propagation still in progress (wait 24-48 hours)
- TTL from previous records not expired yet

### SSL Certificate Not Validating

**Check certificate status:**
```bash
CERT_ARN=$(aws cloudformation describe-stacks --stack-name BBWebHomeProdStack --query "Stacks[0].Outputs[?OutputKey=='CertificateArn'].OutputValue" --output text)

aws acm describe-certificate --certificate-arn $CERT_ARN --region us-east-1
```

**Common issues:**
- DNS validation records not propagated yet
- Nameservers not updated at registrar
- Hosted zone not accessible by ACM

**Solution:** Wait for DNS propagation. ACM will automatically validate once DNS records are accessible.

### Build Fails

**Check Node.js version:**
```bash
node --version  # Should be 18+
```

**Clear cache and rebuild:**
```bash
rm -rf node_modules dist .astro
npm install
npm run build
```

**Check for missing dependencies:**
```bash
npm install
```

## Cost Estimate

**Monthly AWS costs** (assuming low-to-moderate traffic):

| Service | Usage | Cost |
|---------|-------|------|
| Route53 Hosted Zones | 2 zones × $0.50 | $1.00 |
| ACM Certificate | Free tier | $0.00 |
| S3 Storage | ~100 MB | $0.01 |
| S3 Requests | ~10K requests | $0.01 |
| CloudFront | 10 GB transfer + 100K requests | $0.85 |
| **Total** | | **~$1.87/month** |

**Scaling costs** (higher traffic):
- CloudFront: $0.085/GB (first 10 TB)
- S3 Requests: $0.0004 per 1K GET requests
- Route53 Queries: First 1B queries/month included

**Cost optimization tips:**
- CloudFront caching reduces S3 requests significantly
- Static assets cached for 1 year minimize origin requests
- Price Class 100 (North America & Europe) reduces costs vs global

**Monitor costs:**
```bash
# View current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 month ago' +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

Or use [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home) in the AWS Console.

## Contributing

When making changes:

1. **Test locally** with `npm run dev`
2. **Build** to verify: `npm run build`
3. **Deploy to dev** first: `./scripts/deploy.sh dev`
4. **Verify** changes on `dev.brainbridge.app`
5. **Deploy to prod** when ready: `./scripts/deploy.sh prod`

## License

See [LICENSE](LICENSE) file for details.

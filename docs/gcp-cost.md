# Lab 9, Part 3: cost of Spry's core on Google Cloud

Google Cloud prices are the on-demand list prices from the lab handout (USD, us-central1, 730
hours a month, checked by the lecturer on 5 November 2026, no tax). I did not re-check them in
the calculator.

**The AWS column is my own recalculation, not a copy of the Lab 4 table** (I do not have that
table). I did not use the AWS Pricing Calculator either: I took the list prices from public
price pages (sources at the bottom) and multiplied them by the resources that are actually
running, on 18 November 2026. Every AWS number below is `price x quantity x 730 h`, so each one
can be re-checked. The AWS side is what is really deployed (region eu-central-1, no Free Tier
applied). The Google Cloud side is the design in `gcp/`, which was never deployed because
billing could not be activated (see ADR 0008).

## What the AWS side actually is

Fargate (1 task, 0.25 vCPU, 0.5 GB, Linux x86_64, public IP), one internet-facing ALB in 3
zones, RDS PostgreSQL `db.t4g.micro` Single-AZ with 20 GB gp3 (this is plain RDS, not Aurora),
CloudFront (PriceClass_All) in front of an S3 bucket (385.8 KiB), no NAT gateway. Public IPv4
addresses: 3 on the ALB plus 1 on the Fargate task = 4. The RDS instance is not public.

## Reference: nobody uses it for a month

| Piece | AWS (as deployed, eu-central-1) | Google Cloud (my choice) |
|---|---|---|
| Frontend + CDN + HTTPS | CloudFront 1 GB x $0.085 + 10,000 HTTPS x $0.012/10k = $0.10; S3 1 GB x $0.0245 = $0.02; **$0.12** | Firebase Hosting free plan: $0 |
| API | Fargate 0.25 vCPU x $0.04656 x 730 = $8.50 + 0.5 GB x $0.00511 x 730 = $1.87; ALB 730 h x $0.027 = $19.71; public IPv4 4 x $0.005 x 730 = $14.60; **$44.67** | Cloud Run scaled to zero: $0 |
| Database compute | RDS `db.t4g.micro` 730 h x $0.019 = **$13.87** | Cloud SQL `db-f1-micro`, running: 730 h x $0.0105 = $7.67 |
| Database storage | 20 GB gp3 x $0.137 = **$2.74** (backup storage within the free allowance) | 10 GB SSD x $0.17 = $1.70 |
| Registry, secrets, logs | not counted (ECR, CloudWatch Logs, Cognito, ALB capacity units, data transfer out: small at this load) | within the free tier (0.5 GB, 6 secret versions) |
| **Total** | **$61.40** | **$9.37**, or **$1.70** with the instance stopped |

Free-tier assumptions: Cloud Run 2M requests, 180,000 vCPU-seconds and 360,000 GiB-seconds a
month; Artifact Registry 0.5 GB; Secret Manager 6 active versions (I use 2). For AWS no Free
Tier is applied (CloudFront's permanent 1 TB / 10M requests allowance would make that line $0).

AWS traffic assumption: 1 GB a month through CloudFront and 10,000 requests, the same in every
profile. The ALB capacity-unit charge (LCU, $0.008 per LCU-hour) is not counted because traffic
is close to zero; if the ALB averaged 1 LCU all month it would add 730 x $0.008 = $5.84.

## Four traffic profiles (Google Cloud side)

Cloud SQL is stopped outside the hours listed; the stopped instance still pays for storage.

| Profile | Cloud SQL running | Cloud SQL compute | Storage | Cloud Run | Total, Cloud SQL stopped outside use | Total, Cloud SQL always on | Total, Firestore instead |
|---|---|---|---|---|---|---|---|
| Nobody | 0 h | $0.00 | $1.70 | $0 | **$1.70** | $9.37 | $0 |
| Class demos (10 x 2 h) | 20 h | 20 x $0.0105 = $0.21 | $1.70 | $0 | **$1.91** | $9.37 | $0 |
| Office hours (8 h x 22 days) | 176 h | 176 x $0.0105 = $1.85 | $1.70 | $0 | **$3.55** | $9.37 | $0 |
| Busy around the clock | 730 h | $7.67 | $1.70 | $0 if under the free tier | **$9.37** | $9.37 | $0 while under 50,000 reads a day, then $0.03 per 100,000 |

Cloud Run stays at $0 in the first three profiles because student traffic is far below
2M requests and 180,000 vCPU-seconds. Worst case for the last profile, if one container were
actually busy all month at 1 vCPU and 512 MiB: (2,628,000 - 180,000) x $0.000024 = $58.75 for
CPU plus (1,314,000 - 360,000) x $0.0000025 = $2.39 for memory, about $61. Real traffic is
nowhere near this; it is the upper bound.

## Which cloud is cheaper, and which line decides it

| Profile | Google Cloud, Cloud SQL stopped outside use | Google Cloud, Cloud SQL always on | AWS as deployed |
|---|---|---|---|
| Nobody | $1.70 | $9.37 | $61.40 |
| Class demos | $1.91 | $9.37 | $61.40 |
| Office hours | $3.55 | $9.37 | $61.40 |
| Busy around the clock | $9.37 | $9.37 | $61.40 |

On these list prices the Google Cloud design is cheaper in every profile, by roughly 6x even
against Cloud SQL left running, and by 17x to 36x when Cloud SQL is stopped in the light
profiles. The AWS total does not move with traffic, because nothing in this stack scales to zero.

The deciding lines are the always-on pieces: **the ALB ($19.71) plus public IPv4 addresses
($14.60)** together cost $34.31, more than the whole Google Cloud reference total, and they
cannot be paused. Fargate ($10.36) and RDS compute ($13.87) bill every hour too. With the
Fargate task stopped and the RDS instance stopped, AWS still costs about $33.52 a month (ALB
$19.71, 3 ALB addresses $10.95, RDS storage $2.74, CloudFront and S3 $0.12). A stopped RDS
instance is also started again by AWS after 7 days.

Two caveats on fairness:

- **Region.** The handout prices are us-central1; my AWS prices are eu-central-1, which is
  about 20% above us-east-1 for most of these lines. For a check, the same stack at us-east-1
  list prices (Fargate $0.04048 / $0.004445, ALB $0.0225, RDS $0.016 and gp3 $0.115, IPv4
  $0.005) comes to about $54.14 a month. The conclusion does not change.
- **Not the same thing deployed.** The AWS number is a running system; the Google Cloud number
  is a design that was not deployed. Google Cloud also has its free tier applied and AWS does
  not. Cloud Run + Cloud SQL and Fargate + ALB + RDS are similar in role, not identical in
  capacity.

## The equivalent trap on each side

On AWS the trap is that **nothing pauses**: the ALB, its three public IPv4 addresses, the
Fargate task and the RDS instance bill every hour whether or not anyone visits, so an idle
month costs about as much as a busy one (about $61). On GCP the trap is that **Cloud SQL never
pauses**: forget to stop it and every profile costs $9.37. Two related traps: a stopped
instance still bills its 10 GB of storage, and Cloud Run `min instances` above 0 stops it from
scaling to zero.

## Sources of the AWS prices (checked 18 November 2026)

I could not open the AWS price pages themselves, so the figures come from pages that publish
the AWS price list; the IPv4 price is from the AWS blog. Re-check any line in the AWS Pricing
Calculator before relying on it.

- Fargate, eu-central-1, Linux x86: $0.04656 per vCPU-hour, $0.00511 per GB-hour
  (https://vmprices.com/serverless/fargate/)
- ALB, eu-central-1: $0.027 per hour, $0.008 per LCU-hour
  (https://cloudcostdb.com/aws/networking/load-balancers/)
- RDS `db.t4g.micro`, Frankfurt, $0.019 per hour
  (https://www.dbcost.com/instance/db.t4g.micro)
- RDS gp3 / General Purpose SSD storage, Frankfurt Single-AZ: $0.137 per GB-month
  (https://www.cloudbolt.io/wp-content/uploads/the-guide-to-aws-cost-optimization.pdf, an
  undated guide: the least certain number here, worth a calculator check)
- Public IPv4: $0.005 per IP per hour
  (https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights)
- S3 Standard, Frankfurt: $0.0245 per GB-month
  (https://costgoat.com/pricing/amazon-s3)
- CloudFront, Europe: $0.085 per GB for the first 10 TB, $0.012 per 10,000 HTTPS requests
  (https://egresscost.com/aws/cloudfront-pricing/)
- us-east-1 figures for the region check: Fargate (https://www.cloudzero.com/blog/fargate-cost/),
  ALB (https://cloudburn.io/blog/aws-elastic-load-balancing-pricing), RDS
  (https://selfhost.dev/blog/aws-rds-cost-breakdown-2026/)
